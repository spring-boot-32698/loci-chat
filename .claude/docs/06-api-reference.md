# API Reference

All REST endpoints require a valid Keycloak-issued Bearer JWT unless listed in
`SecurityWhitelist` (e.g. actuator/health, swagger-ui, auth endpoints). Auto-generated,
always-current OpenAPI docs are served at `/swagger-ui.html` /
`/v3/api-docs` (springdoc-openapi) when the backend is running; this table is a
hand-curated map for quick orientation. See also the contract-first spec tree in
[`loci-api/`](../../loci-api).

## REST endpoints

### Identity — profile, settings, presence
| Method | Path | Purpose | Controller |
|---|---|---|---|
| GET | `/users/search` | Search users by name/username | `UserIdentityResource` |
| GET | `/users/suggests` | Friend suggestions | `UserIdentityResource` |
| GET | `/users/{publicId}` | Public profile by public id | `UserIdentityResource` |
| GET | `/users/me` | Current user's full profile | `PersonalProfileResource` |
| PATCH | `/users/me` | Update profile (name, bio, …) | `PersonalProfileResource` |
| GET | `/users/me/settings` | Current user's settings | `PersonalProfileResource` |
| PATCH | `/users/me/settings` | Update settings (visibility, friend-request/last-seen policy) | `PersonalProfileResource` |
| PATCH | `/users/me/avatar` | Update avatar image | `PersonalProfileResource` |
| GET | `/presence/{userId}` | One user's presence | `PresenceResource` |
| GET | `/presence` | Bulk presence lookup | `PresenceResource` |
| POST | `/presence/heartbeat` | Keep-alive / refresh online state | `PresenceResource` |
| POST | `/presence/offline` | Explicitly mark self offline | `PresenceResource` |

### Social — friends, contact requests, blocking
| Method | Path | Purpose | Controller |
|---|---|---|---|
| POST | `/contact-requests/{userId}` | Send a contact request | `ContactRequestResource` |
| DELETE | `/contact-requests/{userId}` | Cancel a request sent to `userId` | `ContactRequestResource` |
| GET | `/contact-requests` | List incoming/outgoing requests | `ContactRequestResource` |
| POST | `/contact-requests/{requestId}/accept` | Accept by request id | `ContactRequestResource` |
| POST | `/contact-requests/{requestId}/reject` | Reject by request id | `ContactRequestResource` |
| POST | `/contact-requests/user/{requestUserId}/accept` | Accept by requester's user id | `ContactRequestResource` |
| POST | `/contact-requests/user/{requestUserId}/reject` | Reject by requester's user id | `ContactRequestResource` |
| GET | `/friends` | List current user's friends | `FriendResource` |
| DELETE | `/friends/{friendId}` | Remove a friend | `FriendResource` |
| GET | `/blocks` | List blocked users | `BlockUserResource` |
| POST | `/blocks/{blockUserId}` | Block a user | `BlockUserResource` |
| DELETE | `/blocks/{blockUserId}` | Unblock a user | `BlockUserResource` |

### Conversation
| Method | Path | Purpose | Controller |
|---|---|---|---|
| GET | `/conversations` | List conversations (current user, filtered) | `ConversationResource` |
| GET | `/conversations/user/{userId}` | A user's chat list (`UserChatList`) | `ConversationResource` |
| GET | `/conversations/one/{conversationId}` | 1:1 conversation detail | `ConversationResource` |
| GET | `/conversations/group/{conversationId}` | Group conversation detail | `ConversationResource` |
| POST | `/conversations` | Get-or-create a 1:1 conversation | `ConversationResource` |
| POST | `/conversations/group` | Create a group conversation | `ConversationResource` |
| GET | `/conversations/{conversationId}/messages` | Paginated message history (cursor-based) | `ConversationMessageResource` |
| PATCH | `/conversations/{conversationId}/messages/seen` | Bulk mark-as-read | `ConversationMessageResource` |

### Groups
| Method | Path | Purpose | Controller |
|---|---|---|---|
| GET | `/groups/{groupId}` | Group profile | `GroupResource` |
| PATCH | `/groups/{groupId}` | Update group profile (name, …) | `GroupResource` |
| PATCH | `/groups/{groupId}/image` | Update group picture | `GroupResource` |
| GET | `/groups/{groupId}/participants` | List members | `GroupResource` |
| GET | `/groups/{groupId}/participants/online` | Online members | `GroupResource` |

### Messaging
| Method | Path | Purpose | Controller |
|---|---|---|---|
| POST | `/messages/individual/send` | Send a 1:1 message (REST fallback to STOMP) | `DirectMessageResource` |
| PATCH | `/messages/individual/receive` | Ack delivery of a 1:1 message | `DirectMessageResource` |
| POST | `/messages/group/send` | Send a group message (REST fallback) | `GroupMessageResource` |
| PATCH | `/messages/group/receive` | Ack delivery of a group message | `GroupMessageResource` |
| POST | `/messages/attachment` | Upload a media attachment (multipart) | `MessageResource` |

## WebSocket / STOMP

Handshake endpoints (`WsPaths.ENDPOINT = /ws`, registered together with the more
specific paths below so clients can connect on any of them):

- `/ws`, `/ws/messages`, `/ws/notifications`, `/ws/presence`

Authentication happens at STOMP `CONNECT` (bearer token as a STOMP header), enforced
by `SecurityChannelInterceptorAdapter`; `RateLimitInterceptor` throttles frames.

### Client → Server (`@MessageMapping`, prefixed `/app`)
| Destination | Purpose | Handler |
|---|---|---|
| `/app/individual.send` | Send a 1:1 message | `MessagingWebSocketHandler` |
| `/app/individual/seen` | Mark a 1:1 message as seen | `MessagingWebSocketHandler` |
| `/app/individual/react` | React to a message | `MessagingWebSocketHandler` |
| `/app/group/send` | Send a group message | `MessagingWebSocketHandler` |

### Server → Client (broker destinations, `WsPaths`)
| Destination | Scope | Meaning |
|---|---|---|
| `/user/queue/messages.receive` | per-user | New 1:1 message delivered to you |
| `/user/queue/messages.sent` | per-user | Ack: your message was accepted/sent |
| `/user/queue/messages.delivered` | per-user | Delivery receipt |
| `/user/queue/messages.seen` | per-user | Read receipt |
| `/topic/messages.receive-{conversationId}` | group | New group message broadcast |
| `/user/queue/notifications.new` | per-user | New notification pushed live |
| `/user/queue/notifications.update` | per-user | Notification updated (e.g. read elsewhere) |
| `/topic/presence.group-{groupId}.update` | group | A group member's presence changed |
| `/topic/presence.user-{userId}.update` | per-user (broadcast to watchers) | That user's presence changed |

Frontend counterpart: `loci-frontend/src/app/core/socket/` wraps `@stomp/rx-stomp`
around these same destinations; feature services under
`loci-frontend/src/app/features/{chat,notification}/service` subscribe to them.
