# Business Flows

Sequence diagrams for the primary user journeys, traced against the actual
controllers/handlers/services in `loci-backend` (see file references under each
diagram).

## 1. Authentication & first-request user sync

Loci does not have its own login form — Keycloak owns authentication. The backend's
job is to **trust the JWT** and keep a local mirror of the user for fast relational
queries (friends, conversations, etc. all join against local `user_.id`).

```mermaid
sequenceDiagram
    actor U as User (browser)
    participant FE as Angular (keycloak-angular)
    participant KC as Keycloak
    participant BE as loci-backend
    participant DB as PostgreSQL

    U->>FE: open app
    FE->>KC: redirect to login (OIDC)
    U->>KC: enter credentials
    KC-->>FE: access token (JWT) + refresh token
    FE->>BE: REST/WS request with `Authorization: Bearer <JWT>`
    BE->>BE: OAuth2 Resource Server validates JWT signature/issuer
    BE->>BE: JwtUserSyncFilter converts token -> User (KeycloakJwtTokenConverter)
    BE->>DB: UserSynchronizeService.syncUser() upsert local user_ row
    BE-->>FE: proceed to requested resource
```

Key files: `common/authentication/infrastructure/primary/filter/JwtUserSyncFilter.java`,
`.../keycloak/KeycloakJwtTokenConverter.java`,
`common/user/domain/service/UserSynchronizeService.java`,
`common/authentication/infrastructure/primary/config/SecurityConfiguration.java`.

WebSocket connections are authenticated separately at STOMP CONNECT time via
`SecurityChannelInterceptorAdapter` + `WebSocketAuthenticationManager`
(`common/websocket/infrastructure/primary/security/`), using the same bearer token
passed as a STOMP header.

## 2. Becoming friends (contact request lifecycle)

```mermaid
sequenceDiagram
    actor A as User A
    actor B as User B
    participant BE as loci-backend
    participant DB as PostgreSQL
    participant WS as WebSocket (notifications)

    A->>BE: POST /contact-requests/{userIdOfB}
    BE->>BE: ContactRequestResource -> SocialApplicationService -> FriendManager
    BE->>DB: insert contact_request (status=PENDING)
    BE->>WS: publish Notification "new contact request" to B
    WS-->>B: /user/queue/notifications.new

    alt B accepts
        B->>BE: POST /contact-requests/{requestId}/accept
        BE->>DB: update contact_request.status=ACCEPTED
        BE->>DB: insert contact rows (A<->B, both directions)
        BE->>WS: notify A "request accepted"
    else B rejects
        B->>BE: POST /contact-requests/{requestId}/reject
        BE->>DB: update contact_request.status=DECLINED
    end
```

Key files: `core/social/infrastructure/primary/resource/ContactRequestResource.java`,
`core/social/application/SocialApplicationService.java`,
`core/social/domain/service/FriendManager.java`,
`core/social/domain/aggregate/{ContactRequest,ContactConnection}.java`.

A `FriendshipStatus`/`FriendRequestStatus` state machine backs this
(`PENDING → ACCEPTED | DECLINED | CANCELED`); either side can also cancel a pending
outgoing request via `DELETE /contact-requests/{userId}`.

Related: **Discovery** (`core/discovery`) powers `GET /users/search` and
`GET /users/suggests`, which is how User A finds User B in the first place, and
**Blocking** (`BlockUserResource`) lets either party cut off contact regardless of
friendship state — `MessagingPolicy`/`UserIsBlockedByOtherException` enforce that a
blocked relationship prevents new messages.

## 3. Starting a conversation

Two entry points, both producing a `Conversation` aggregate:

```mermaid
sequenceDiagram
    actor A as User A
    participant BE as loci-backend
    participant DB as PostgreSQL

    rect rgb(235,245,255)
    note over A,BE: 1:1 chat — implicit / on demand
    A->>BE: POST /conversations  (peer userId)
    BE->>BE: ConversationApplicationService -> ConversationCreator
    BE->>DB: find existing ONE_TO_ONE conversation for the pair, else create it
    BE-->>A: Conversation (id, type=ONE_TO_ONE, participants)
    end

    rect rgb(245,235,255)
    note over A,BE: Group chat — explicit creation
    A->>BE: POST /conversations/group  { name, memberPublicIds[] }
    BE->>BE: ConversationApplicationService -> GroupManager / GroupPolicy
    BE->>DB: insert conversation(type=GROUP), group_, conversation_participant* (creator=ADMIN)
    BE-->>A: CreatedGroupConversationResponse
    end
```

Key files: `core/conversation/infrastructure/primary/resource/ConversationResource.java`,
`core/conversation/domain/service/{ConversationCreator,ConverationManagerService}.java`,
`core/groups/domain/service/{GroupManager,GroupMembershipService,GroupPolicy}.java`,
`core/groups/domain/factory/ConversationParticipantFactory.java`.

A user's conversation list (`GET /conversations/user/{userId}`) returns a
`UserChatList` — each entry carries the last message preview and unread count
(`ConversationUnreadMessageCount`), used to render the chat inbox.

## 4. Sending & receiving a direct (1:1) message

The primary interactive real-time path — REST is available as a fallback/initial
send, but STOMP is the live channel both sender and receiver actually listen on.

```mermaid
sequenceDiagram
    actor A as Sender
    actor B as Recipient
    participant WS as MessagingWebSocketHandler
    participant APP as MessagingApplicationService
    participant DOM as MessageManager / MessageSendingService
    participant DB as PostgreSQL
    participant Broker as STOMP broker (RabbitMQ/in-memory)

    A->>WS: SEND /app/individual.send  { conversationId, content }
    WS->>APP: sendDirectMessage(request)
    APP->>DOM: validate (ValidationService, MessagingPolicy: not blocked, is participant)
    DOM->>DB: insert message (status=PREPARE -> SENT)
    DOM->>Broker: publish to sender's /user/queue/messages.sent (ack)
    DOM->>Broker: publish to recipient's /user/queue/messages.receive
    Broker-->>A: delivery ack (message id, sentAt)
    Broker-->>B: new message payload

    B->>WS: SEND /app/individual/seen  { messageId }
    WS->>APP: markSeen(request)
    APP->>DB: update message.status=SEEN, read_at, conversation_participant.last_read_message_id
    APP->>Broker: notify sender via /user/queue/messages.seen
    Broker-->>A: read receipt
```

Key files: `core/messaging/infrastructure/primary/handler/MessagingWebSocketHandler.java`,
`core/messaging/application/MessagingApplicationService.java`,
`core/messaging/domain/service/{MessageSendingService,MessageManager,MessageTrackingStateService,MessagingPolicy}.java`,
`core/messaging/infrastructure/secondary/realtime/SpringWebSocketDirectMessage{Notifier,Publisher}.java`,
`common/websocket/infrastructure/WsPaths.java` (`INDIVIDUAL_*` destinations).

`MessageState`/`MessageStatus` model the lifecycle: `PREPARE → SENT → DELIVERED → SEEN`.
A `MessageSentEvent` domain event fires on successful send, which is how
downstream concerns (e.g. notification/analytics) can react without coupling into the
sending code path.

REST equivalents exist for non-realtime/initial-load use: `POST
/messages/individual/send`, `PATCH /messages/individual/receive`, and
`GET /conversations/{id}/messages` (paginated history via `MessageCursorQuery`),
`PATCH /conversations/{id}/messages/seen` (bulk mark-as-read).

## 5. Sending a group message

Same shape as 1:1, but fan-out is to a **topic** (all group members) instead of a
single recipient queue:

```mermaid
sequenceDiagram
    actor A as Sender (group member)
    participant WS as MessagingWebSocketHandler
    participant APP as MessagingApplicationService
    participant DB as PostgreSQL
    participant Broker as STOMP broker

    A->>WS: SEND /app/group/send  { conversationId, content }
    WS->>APP: sendGroupMessage(request)
    APP->>DB: verify sender is participant (Group), not blocked by any member policy check
    APP->>DB: insert message
    APP->>Broker: publish to /topic/messages.receive-{conversationId}
    Broker-->>Others: all subscribed group members receive it in real time
    APP->>Broker: publish sent/delivered acks to sender's /user/queue/*
```

Key files: `core/messaging/infrastructure/primary/resource/GroupMessageResource.java`,
`core/messaging/infrastructure/secondary/realtime/SpringWebSocketGroupMessage{Notifier,Publisher}.java`,
`core/groups/domain/service/GroupPolicy.java` (who may post in a group).

## 6. Media/attachment upload

```mermaid
sequenceDiagram
    actor A as User
    participant BE as loci-backend
    participant Store as MinIO (S3-compatible)
    participant DB as PostgreSQL

    A->>BE: POST /messages/attachment  (multipart file)
    BE->>BE: FileStorageService (common/store) validates + resolves path
    BE->>Store: PUT object
    Store-->>BE: object URL/key
    BE-->>A: RestAttachment { mediaUrl, mediaName, contentType }
    A->>BE: SEND /app/individual.send or /app/group/send with type=IMAGE/VIDEO/FILE, mediaUrl
    BE->>DB: insert message referencing the media
```

Key files: `core/messaging/infrastructure/primary/resource/MessageResource.java`,
`common/store/domain/service/FileStorageService.java`,
`common/store/infrastructure/secondary/minio/MinioObjectStorage.java`,
`common/store/infrastructure/secondary/s3/S3FileService.java` (alternate adapter),
`common/store/infrastructure/secondary/local/LocalObjectStorage.java` (dev fallback).

## 7. Presence tracking

```mermaid
sequenceDiagram
    actor A as User A
    participant WS as UserPresenceWebSocketHandler
    participant Session as PresenceSessionListener
    participant Cache as Redis/Caffeine
    participant Broker as STOMP broker
    actor Watchers as Friends/Group members

    A->>WS: WebSocket CONNECT to /ws/presence
    Session->>Cache: mark A ONLINE, record session
    WS->>Broker: publish /topic/presence.user-{A}.update {ONLINE}
    Broker-->>Watchers: presence update

    A-->>WS: heartbeat (POST /presence/heartbeat) periodically
    WS->>Cache: refresh A's last-active timestamp

    A->>WS: disconnect / connection drops
    Session->>Cache: mark A OFFLINE / record last_active
    WS->>Broker: publish /topic/presence.user-{A}.update {OFFLINE, lastActive}
    Broker-->>Watchers: presence update
```

Key files: `core/identity/infrastructure/primary/handler/UserPresenceWebSocketHandler.java`,
`core/identity/infrastructure/primary/listener/PresenceSessionListener.java`,
`core/identity/domain/service/{PresenceIndicator,UserPresenceService}.java`,
`core/identity/infrastructure/secondary/repository/CacheUserPresenceRepository.java`,
`core/identity/infrastructure/primary/resource/PresenceResource.java`
(`GET /presence/{userId}`, `GET /presence` bulk, `POST /presence/heartbeat`,
`POST /presence/offline`).

Group-level presence (who in a group is currently online) is a separate concern in
`core/groups` (`GroupPresence`, `SpringWebSocketGroupPresenceNotifier`,
`STOMPPresenceTrackingOperations`), broadcast to `/topic/presence.group-{id}.update`.

## 8. Notifications

```mermaid
sequenceDiagram
    participant Source as Any context (Social, Messaging, ...)
    participant Engine as NotificationEngine
    participant DB as PostgreSQL
    participant Broker as STOMP broker
    actor U as Recipient

    Source->>Engine: domain event (e.g. contact request received)
    Engine->>DB: insert notification (content, thumbnail, read_at=null)
    Engine->>Broker: publish /user/queue/notifications.new
    Broker-->>U: real-time push (if online)
    U->>Engine: (later) GET notifications / mark read
    Engine->>DB: update notification.read_at
```

Key files: `core/notification/domain/service/NotificationEngine.java`,
`core/notification/infrastructure/secondary/realtime/{SpringWebSocketNotificationPublisher,STOMPPushNotificationOperations}.java`,
`core/notification/infrastructure/primary/handler/NotificationWebSocketHandler.java`.

This is intentionally decoupled: any bounded context can trigger a notification
without depending on how it's delivered — it's persisted (so it survives being
offline) *and* pushed live (so it's instant when online).
