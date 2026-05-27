import '../error/result.dart';

/// Outcome of a sync cycle, for surfacing status in the UI ("Last synced 5m
/// ago", "3 changes pending").
class SyncOutcome {
  const SyncOutcome({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictCount,
    required this.serverTime,
  });

  final int pushedCount;
  final int pulledCount;
  final int conflictCount;
  final int serverTime;
}

/// Orchestrates push-then-pull synchronisation between the local Drift database
/// and the FastAPI backend.
///
/// FOUNDATION STAGE: this is the contract only. The concrete implementation is
/// built at step 7 of the build sequence, once the feature tables have real
/// repositories to collect dirty rows from and apply incoming rows to. Defining
/// the interface now lets feature code depend on the abstraction immediately.
///
/// Contract (see ARCHITECTURE.md §6):
///   1. PUSH all `is_dirty` rows, ordered parents → children.
///   2. On success clear `is_dirty` / set `last_synced_at` for applied rows;
///      adopt any conflict-winner rows the server returns.
///   3. PULL everything changed since the stored server-time cursor; apply via
///      last-write-wins; persist the new cursor.
///   4. The whole cycle is idempotent and safe to retry after a dropped link.
abstract interface class SyncEngine {
  /// Run one full push-then-pull cycle. Safe to call when offline — it should
  /// return a [NetworkFailure] without throwing.
  Future<Result<SyncOutcome>> sync();

  /// Number of locally-changed rows awaiting upload (for a "pending" badge).
  Future<int> pendingChangeCount();
}
