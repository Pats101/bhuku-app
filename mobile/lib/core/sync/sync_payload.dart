/// Wire types for the sync protocol (`/sync/push`, `/sync/pull`).
///
/// These mirror the FastAPI Pydantic schemas in `backend/app/modules/sync`.
/// Rows are sent as untyped JSON maps keyed by table name; each table's
/// repository knows how to (de)serialise its own rows. This keeps the sync
/// engine generic — it shuttles maps and does not need to know every column.
library;

/// A bundle of changed rows grouped by table name.
///
/// Order is significant on apply: parents (products, customers) before
/// children (sales → sale_items → debts → debt_payments) so foreign keys
/// always resolve. See ARCHITECTURE.md §6.
typedef ChangeSet = Map<String, List<Map<String, dynamic>>>;

/// Body of `POST /sync/push`.
class PushRequest {
  const PushRequest({required this.changes});
  final ChangeSet changes;

  Map<String, dynamic> toJson() => {'changes': changes};
}

/// Response of `POST /sync/push`.
class PushResponse {
  const PushResponse({required this.appliedIds, required this.conflicts});

  /// Ids the server accepted — the client clears `is_dirty` for these.
  final List<String> appliedIds;

  /// Rows the server rejected under last-write-wins; payload is the winning
  /// server row, which the client should adopt locally.
  final List<Map<String, dynamic>> conflicts;

  factory PushResponse.fromJson(Map<String, dynamic> json) => PushResponse(
        appliedIds:
            (json['applied'] as List).map((e) => e as String).toList(),
        conflicts: (json['conflicts'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
      );
}

/// Body of `POST /sync/pull`.
class PullRequest {
  const PullRequest({required this.since});

  /// Epoch-ms cursor: "give me everything changed after this". 0 = full pull.
  /// This cursor is **server time**, never device time — cheap Android clocks
  /// drift and must not drive cross-device ordering. See ARCHITECTURE.md §6.
  final int since;

  Map<String, dynamic> toJson() => {'since': since};
}

/// Response of `POST /sync/pull`.
class PullResponse {
  const PullResponse({required this.changes, required this.serverTime});
  final ChangeSet changes;

  /// New cursor to persist and send as `since` next time.
  final int serverTime;

  factory PullResponse.fromJson(Map<String, dynamic> json) => PullResponse(
        changes: (json['changes'] as Map).map(
          (table, rows) => MapEntry(
            table as String,
            (rows as List)
                .map((e) => (e as Map).cast<String, dynamic>())
                .toList(),
          ),
        ),
        serverTime: json['server_time'] as int,
      );
}
