# Overview & Business Domain

## What is Loci?

Loci is a real-time messaging application — the same product category as
Messenger/WhatsApp/Telegram, scoped down to a learning/portfolio-grade feature set:

- **Direct (1:1) messaging** with delivery/read status tracking
- **Group messaging** with membership management
- **Media sharing** (images, video, files) via object storage
- **Presence** — who's online, last-active tracking
- **Contact management** — friend requests, friends list, blocking
- **Notifications** — pushed in real time over WebSocket
- **Authentication & profile** — Keycloak-backed identity, editable profile/settings

## Core business concepts (ubiquitous language)

These names are used consistently in the code (packages, classes) and in this
documentation — using them precisely avoids ambiguity.

| Term | Meaning |
|---|---|
| **User** | A registered identity, backed by Keycloak, mirrored locally for fast joins/queries. |
| **Profile** | The user-facing view of a User: name, bio, avatar, visibility settings. |
| **Presence** | A user's live online/offline/away state, broadcast to interested parties. |
| **Contact / Friend** | A bidirectional social connection between two Users, established via a Contact Request. |
| **Contact Request** | A pending invitation from one User to another to become contacts; can be accepted/rejected/canceled. |
| **Block** | A one-directional restriction preventing a blocked User from messaging/contacting the blocker. |
| **Conversation** | The thread a set of Participants exchange Messages in. Two types: `ONE_TO_ONE` and `GROUP`. |
| **Participant** | A User's membership record inside a Conversation (role: `ADMIN` or `MEMBER`, read-cursor). |
| **Group** | The profile (name, picture) attached to a `GROUP`-type Conversation. |
| **Message** | A single unit of content (`TEXT`, `FILE`, `IMAGE`, `VIDEO`) sent into a Conversation, with a lifecycle status. |
| **Message status** | `PREPARE → SENT → DELIVERED → SEEN`, tracked per message (and effectively per-recipient in a 1:1 chat). |
| **Notification** | An async, user-facing event (e.g. new contact request) pushed over WebSocket and persisted for later reading. |

## Bounded contexts (business capabilities)

The backend is explicitly split into these business capabilities (see
[Architecture](03-architecture.md) for how this maps to code):

- **Identity** — profile, personal settings, presence
- **Social** — friends, contact requests, blocking
- **Discovery** — user search, friend suggestions
- **Conversation** — conversation lifecycle (create 1:1 / group, list, read)
- **Groups** — group profile & membership management
- **Messaging** — sending/receiving messages, delivery/read receipts, attachments
- **Notification** — real-time + persisted notifications
- **Common/Authentication** — Keycloak-backed auth, JWT, user sync
- **Common/Store** — file/media storage abstraction (MinIO/S3/local)

## Primary user journeys

1. **Sign up / log in** via Keycloak → land on `user/me` (own profile).
2. **Find people**: search users, view suggested friends → send a contact request.
3. **Become friends**: recipient accepts/rejects the contact request.
4. **Start chatting**: open (or auto-create) a 1:1 conversation with a friend, or create a group with several friends.
5. **Exchange messages**: text or media messages stream in real time; sender sees delivered/seen receipts; presence indicator shows if the other party is online.
6. **Manage relationships**: block an abusive user, remove a friend, manage group membership/profile.
7. **Stay informed**: notifications (e.g. "X sent you a contact request") arrive live and are visible in a notification center even if the user was offline when they happened.

See [Business Flows](04-business-flows.md) for the concrete sequence diagrams behind
each of these journeys.
