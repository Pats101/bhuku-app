"""Wire schemas for the sync protocol. Mirror the Flutter `sync_payload.dart`."""
from pydantic import BaseModel, Field

# Rows are untyped maps keyed by table name; each table validates its own rows
# against the ORM model on apply. This keeps the sync envelope generic.
ChangeSet = dict[str, list[dict]]


class PushRequest(BaseModel):
    changes: ChangeSet = Field(default_factory=dict)


class PushResponse(BaseModel):
    # Ids the server accepted; the client clears `is_dirty` for these.
    applied: list[str]
    # Rows the client lost under last-write-wins; each is the winning server row.
    conflicts: list[dict]


class PullRequest(BaseModel):
    # Epoch-ms cursor (server time). 0 = full initial pull.
    since: int = 0


class PullResponse(BaseModel):
    changes: ChangeSet
    # New cursor the client persists and sends as `since` next time.
    server_time: int
