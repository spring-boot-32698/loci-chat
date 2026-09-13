# Architecture

The backend (`loci-backend`) is built as **Hexagonal Architecture (Ports & Adapters)**
with **Domain-Driven Design** tactical patterns, organized into **bounded contexts**.
The project's own root `README.md` includes hand-drawn diagrams
(`assets/architecture.png`, `assets/hexagonal.png`, `assets/ddd-modeling.png`) — the
diagrams below express the same structure from the actual source tree.

## 1. High-level system architecture

```mermaid
flowchart LR
    subgraph Client["Browser (Angular SPA)"]
        UI[Angular App]
        Stomp[RxStomp / SockJS client]
    end

    subgraph Edge["Nginx (reverse proxy + TLS)"]
    end

    subgraph Backend["loci-backend (Spring Boot)"]
        REST[REST Controllers\n'Resources']
        WS[STOMP WebSocket Handlers]
        APP[Application Services]
        DOM[Domain Model\n'core/*']
        SEC[Security / JWT filter chain]
    end

    IDP[(Keycloak\nOAuth2 / OIDC)]
    DB[(PostgreSQL)]
    Cache[(Redis / Caffeine)]
    MQ[(RabbitMQ\nSTOMP relay)]
    Store[(MinIO / S3\nobject storage)]
    Prom[(Prometheus + Grafana)]

    UI -- HTTPS REST --> Edge
    Stomp -- WSS/STOMP --> Edge
    Edge --> REST
    Edge --> WS
    REST --> SEC --> APP
    WS --> SEC
    APP --> DOM
    DOM -- ports --> DB
    DOM -- ports --> Cache
    DOM -- ports --> Store
    WS <-- pub/sub relay --> MQ
    UI -. OIDC login/token .-> IDP
    SEC -. validate JWT .-> IDP
    Backend -. metrics .-> Prom
```

## 2. Hexagonal layering (per bounded context)

Every business module under `core/<context>` and `common/<concern>` follows the same
three-layer shape:

```mermaid
flowchart TB
    subgraph Primary["infrastructure/primary  (driving adapters)"]
        RestCtrl["REST Resource\n(@RestController)"]
        WsHandler["WebSocket Handler\n(@MessageMapping)"]
        RestMapper["Rest ⇄ Domain Mapper"]
    end

    subgraph Application["application  (use-case orchestration)"]
        AppSvc["*ApplicationService"]
    end

    subgraph Domain["domain  (framework-free business logic)"]
        Aggregate["Aggregates / Value Objects"]
        DomainSvc["Domain Services"]
        Port["Repository / Notifier / Publisher\ninterfaces (ports)"]
    end

    subgraph Secondary["infrastructure/secondary  (driven adapters)"]
        Jpa["Jpa*Repository (Spring Data)"]
        Entity["*Entity (JPA)"]
        Realtime["SpringWebSocket*Notifier/Publisher"]
        EntityMapper["Entity ⇄ Domain Mapper"]
    end

    RestCtrl --> RestMapper --> AppSvc
    WsHandler --> AppSvc
    AppSvc --> DomainSvc
    AppSvc --> Aggregate
    DomainSvc --> Port
    Port -.implemented by.-> Jpa
    Port -.implemented by.-> Realtime
    Jpa --> Entity
    Jpa --> EntityMapper
```

- **Domain** never imports Spring/JPA/web types — only `common/ddd` contracts
  (`DomainEvent`, `ValueObject`) and validation helpers (`common/validation`).
- **Ports** are plain interfaces declared *in* the domain package
  (`domain/repository/*Repository`, `domain/repository/*Notifier`,
  `domain/repository/*Publisher`) — the domain defines what it needs, infrastructure
  provides it.
- **Primary adapters** ("driving" — things that call into the app) are REST resources
  and STOMP `@MessageMapping` handlers.
- **Secondary adapters** ("driven" — things the app calls out to) are Spring Data JPA
  repositories, MinIO/S3 storage, Redis/Caffeine caches, and the WebSocket
  publish/notify implementations.
- **Stereotype annotations** (`common/ddd/infrastructure/stereotype`:
  `@ApplicationService`, `@DomainService`, `@PrimaryPort`, `@SecondaryPort`,
  `@PrimaryMapper`, `@SecondaryMapper`, `@Acl`) make the layer of every class
  explicit and enforce the dependency direction at a glance.

## 3. Bounded context map (`core/*`)

```mermaid
flowchart TB
    Identity[Identity\nprofile, settings, presence]
    Social[Social\nfriends, contact requests, blocking]
    Discovery[Discovery\nuser search, suggestions]
    Conversation[Conversation\n1:1 & group thread lifecycle]
    Groups[Groups\ngroup profile & membership]
    Messaging[Messaging\nsend/receive, receipts, attachments]
    Notification[Notification\nreal-time + persisted alerts]
    Auth[common/authentication\nKeycloak JWT, user sync]
    Store[common/store\nMinIO/S3/local files]
    UserCore[common/user\nshared User aggregate]

    Auth --> UserCore
    Identity --> UserCore
    Social --> Discovery
    Discovery --> UserCore
    Conversation --> Groups
    Conversation --> Identity
    Messaging --> Conversation
    Messaging --> Store
    Messaging --> Notification
    Social --> Notification
    Groups --> Identity
```

- **`common/user`** holds the shared `User` aggregate (identity, email, names) used
  across contexts — each context (`Identity`, `Social`, `Discovery`, …) builds its own
  aggregates/value-objects *around* a `User` reference (e.g. `Friend`, `Participant`,
  `PersonalProfile`) rather than sharing a god-object.
- **Anti-corruption layers (ACL)**: `core/conversation/domain/acl/ConversationGroupAcl`
  is an explicit ACL so the Conversation context can consult Group data without
  depending on Groups' internal model — this is the DDD pattern the `@Acl` /
  `AntiDomainService` stereotypes exist for.
- **Domain events**: `core/groups/application/event/CreateGroupEvent` and
  `core/messaging/domain/event/MessageSentEvent` decouple side effects (e.g.
  notifying, presence updates) from the triggering use case via
  `SpringDomainEventPublisher`.

## 4. Real-time transport layer

```mermaid
flowchart LR
    subgraph Client
        A[Angular RxStomp client]
    end
    subgraph Backend
        WS["/ws, /ws/messages,\n/ws/notifications, /ws/presence\n(STOMP endpoints)"]
        SecInterceptor[SecurityChannelInterceptorAdapter\n+ RateLimitInterceptor]
        Handlers["@MessageMapping handlers\n(Messaging, Presence, Notification)"]
    end
    Broker{{STOMP relay}}
    RabbitMQ[(RabbitMQ)]
    InMemory[[In-memory broker]]

    A <-- WSS handshake + STOMP frames --> WS
    WS --> SecInterceptor --> Handlers
    Handlers -- publish to /topic, /queue --> Broker
    Broker -.type=rabbitmq.-> RabbitMQ
    Broker -.type=inmemory.-> InMemory
    Broker -- fan out --> A
```

- `/topic/*` destinations are **group broadcast** (e.g. `messages.receive-{conversationId}`,
  `presence.group-{id}.update`); `/queue/*` destinations are **per-user** (delivered
  via STOMP's `/user/**` convention), e.g. `messages.sent`, `notifications.new`.
- The broker relay is swappable (`stomp.relay.type: rabbitmq | inmemory`) — RabbitMQ is
  used in dev/stage for realistic pub/sub fan-out and horizontal scalability; the
  in-memory broker is a lighter-weight fallback.
- WebSocket handshake authentication and per-frame authorization run through
  `SecurityChannelInterceptorAdapter`; `RateLimitInterceptor` throttles inbound frames
  independently of the HTTP-side `RateLimitingFilter`.

## Package layout cheat sheet

```
loci_backend/
├── common/                      # cross-cutting / shared kernel
│   ├── authentication/          # Keycloak JWT verification, user sync, security filters
│   ├── cache/                   # Caffeine/Redis cache abstractions
│   ├── ddd/                     # DDD tactical building blocks & stereotypes (framework-free)
│   ├── jpa/                     # shared JPA base classes (auditing, paging)
│   ├── log/                     # AOP-based execution logging
│   ├── migration/               # one-off Keycloak user migration (Spring Shell command)
│   ├── store/                   # file storage port + Minio/S3/local adapters
│   ├── user/                    # shared User aggregate + repository
│   ├── validation/              # domain assertions, RFC7807 ProblemDetail error mapping
│   ├── websocket/                # STOMP config, security, broker autoconfiguration
│   └── wire/                     # Spring @Configuration classes wiring the above together
└── core/                         # bounded contexts (business capabilities)
    ├── identity/                 # profile, settings, presence
    ├── social/                   # friends, contact requests, blocking
    ├── discovery/                 # search, suggestions
    ├── conversation/             # conversation lifecycle
    ├── groups/                   # group profile & membership
    ├── messaging/                 # message send/receive/receipts/attachments
    └── notification/              # notifications
```

Each `core/<context>` and most of `common/<concern>` follows:
`application/ · domain/{aggregate,vo,repository,service,exception,event,acl}/ · infrastructure/{primary,secondary}/`.
