import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

// Drift generates this file. Run: `dart run build_runner build`.
part 'database.g.dart';

/// The single local SQLite database — Bhuku's source of truth.
///
/// Everything the app shows is read from here; nothing in the UI blocks on the
/// network. The sync engine reconciles this with the backend in the background.
@DriftDatabase(
  tables: [Products, Customers, Sales, SaleItems, Debts, DebtPayments],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Bump this when tables change, and add the step to [migration].
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Enforce foreign keys at the SQLite level.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static LazyDatabase _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'bhuku.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
