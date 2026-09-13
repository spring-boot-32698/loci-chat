# Data Model

Source of truth: `loci-backend/src/main/resources/db/migrations/V1__baseline.sql`
(Flyway-managed; PostgreSQL). All primary keys are `bigint` sequences; most tables
also carry a public-facing `uuid` (`public_id`) so internal IDs never leak into the
API/URLs.

## Entity-relationship diagram

```mermaid
erDiagram
    USER ||--o{ CONTACT : "user_id"
    USER ||--o{ CONTACT : "contact_user_id (as target)"
    USER ||--o{ CONTACT_REQUEST : "request_user_id"
    USER ||--o{ CONTACT_REQUEST : "receiver_user_id"
    USER ||--o{ CONVERSATION : "creator_id"
    USER ||--o{ CONVERSATION_PARTICIPANT : "user_id"
    USER ||--o{ MESSAGE : "sender_id"
    USER ||--o{ NOTIFICATION : "user_id"
    USER ||--|| USER_SETTING : "user_id"
    USER ||--o{ USER_AUTHORITY : "user_id"
    AUTHORITY ||--o{ USER_AUTHORITY : "authority_name"

    CONVERSATION ||--o{ CONVERSATION_PARTICIPANT : "conversation_id"
    CONVERSATION ||--o{ MESSAGE : "conversation_id"
    CONVERSATION ||--o| GROUP_ : "conversation_id (1:1, GROUP type only)"
    CONVERSATION }o--|| MESSAGE : "last_message_id"

    MESSAGE }o--o| MESSAGE : "reply_to_message_id (self, threaded reply)"

    USER {
        bigint id PK
        uuid public_id
        varchar email UK
        varchar username UK
        varchar firstname
        varchar lastname
        varchar bio
        varchar profile_picture
        timestamptz last_active
    }

    USER_SETTING {
        bigint user_id PK, FK
        boolean profile_visibility
        varchar friend_request_setting "EVERYONE|FRIENDS_OF_FRIENDS|NOBODY"
        varchar last_seen_setting "EVERYONE|CONTACT_ONLY|NOBODY"
    }

    AUTHORITY {
        varchar name PK
    }

    USER_AUTHORITY {
        bigint user_id PK, FK
        varchar authority_name PK, FK
    }

    CONTACT {
        bigint id PK
        bigint user_id FK
        bigint contact_user_id FK
        bigint blocked_by FK "nullable; who blocked whom"
    }

    CONTACT_REQUEST {
        bigint id PK
        uuid public_id UK
        bigint request_user_id FK
        bigint receiver_user_id FK
        varchar status "PENDING|ACCEPTED|DECLINED|CANCELED"
    }

    CONVERSATION {
        bigint id PK
        uuid public_id UK
        varchar conversation_type "ONE_TO_ONE|GROUP"
        bigint creator_id FK
        boolean deleted
        bigint last_message_id FK
        timestamptz last_message_sent
    }

    CONVERSATION_PARTICIPANT {
        bigint id PK
        bigint conversation_id FK
        bigint user_id FK
        varchar role "ADMIN|MEMBER"
        bigint last_read_message_id "read cursor"
    }

    GROUP_ {
        bigint id PK
        uuid public_id UK
        bigint conversation_id FK "unique (1:1 with CONVERSATION)"
        varchar group_name
        varchar group_profile_picture
        timestamptz last_active
    }

    MESSAGE {
        bigint id PK
        uuid public_id UK
        bigint conversation_id FK
        bigint sender_id FK
        bigint reply_to_message_id FK "nullable, self-ref"
        varchar type "TEXT|FILE|IMAGE|VIDEO"
        text content
        varchar media_name
        varchar media_url
        varchar status "PREPARE|SENT|DELIVERED|SEEN"
        timestamptz sent_at
        timestamptz delivered_at
        timestamptz read_at
        boolean deleted
    }

    NOTIFICATION {
        bigint id PK
        uuid public_id UK
        bigint user_id FK "recipient"
        text content
        varchar message_thumbnail
        timestamptz read_at "nullable = unread"
    }
```

## Notes / conventions

- **Soft delete**: `conversation.deleted` and `message.deleted` are boolean flags —
  rows are not physically removed, allowing message history to stay consistent for
  other participants even if one side "deletes" a conversation from their own view.
- **Public IDs**: every externally-addressable aggregate root exposes a `uuid
  public_id` in the REST/WS payloads instead of the internal `bigint` sequence id —
  see `common/translation/IdTranslator` and per-context `*IdTranslator` ports, plus
  `common/user/domain/vo/PublicId.java`.
- **`CONTACT` is directional-but-symmetric**: accepting a contact request inserts
  contact rows so the relationship is queryable from either `user_id` or
  `contact_user_id`; `blocked_by` records which side (if any) has blocked the
  relationship without deleting the row (so unblocking restores the friendship).
- **1:1 vs. group conversations share one table** (`conversation`), discriminated by
  `conversation_type`; a `GROUP` conversation additionally has exactly one `group_`
  row (name/photo), whereas `ONE_TO_ONE` does not.
- **Read receipts** are modeled two ways simultaneously: per-message
  (`message.status`, `read_at`) for the classic "seen" tick, and per-participant
  (`conversation_participant.last_read_message_id`) as a cursor for unread-count
  queries (`ConversationUnreadMessageCount`) without scanning every message.
- **`data.sql`** (alongside `V1__baseline.sql`) seeds baseline reference data
  (e.g. `authority` rows) on startup in dev-oriented profiles.
