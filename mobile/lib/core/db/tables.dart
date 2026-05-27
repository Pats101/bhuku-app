import 'package:drift/drift.dart';

/// Columns shared by every syncable business table.
///
/// This mixin is the single definition of our sync contract on the client.
/// Defining it once guarantees every table syncs the same way — the most
/// important invariant in an offline-first schema.
///
/// Timestamps are stored as **epoch milliseconds (UTC)** integers, not
/// `DateTime` text, because integers are compact, sort correctly, and compare
/// cheaply for last-write-wins. See ARCHITECTURE.md §5/§6.
mixin SyncColumns on Table {
  /// Client-generated UUIDv4. Lets an offline device create rows (and the
  /// foreign keys between them) with no server round-trip. Primary key.
  TextColumn get id => text()();

  /// Tenant scope. For the MVP this equals the owner's Supabase user id.
  TextColumn get shopId => text().named('shop_id')();

  IntColumn get createdAt => integer().named('created_at')();

  /// Bumped on every local write; drives last-write-wins conflict resolution.
  IntColumn get updatedAt => integer().named('updated_at')();

  /// Soft delete. A delete is just a row with this set — it syncs like any
  /// other change so the deletion can travel between devices. Never hard-delete.
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();

  // --- LOCAL-ONLY columns (never sent to the server) ---

  /// True when the row has local changes not yet confirmed by the server.
  /// This flag IS the sync queue — no separate change-log table needed.
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(true))();

  IntColumn get lastSyncedAt =>
      integer().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inventory items.
class Products extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();

  /// Unit of measure, e.g. `each`, `kg`, `litre`.
  TextColumn get unit => text().withDefault(const Constant('each'))();

  IntColumn get costPriceMinor => integer().named('cost_price_minor')();
  IntColumn get sellPriceMinor => integer().named('sell_price_minor')();
  TextColumn get currency => text()();

  /// Real to support fractional stock (e.g. 2.5 kg). See ARCHITECTURE.md §5 for
  /// the single-device assumption around mutating this field.
  RealColumn get quantity => real().withDefault(const Constant(0))();

  /// Below this level the dashboard flags a low-stock alert.
  RealColumn get reorderLevel =>
      real().named('reorder_level').withDefault(const Constant(0))();
}

/// Customers — the debt ledger is organised per customer.
class Customers extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
}

/// A sale transaction (header). Line items live in [SaleItems].
class Sales extends Table with SyncColumns {
  /// Null = walk-in cash sale with no tracked customer.
  TextColumn get customerId => text().named('customer_id').nullable()();

  IntColumn get soldAt => integer().named('sold_at')();
  TextColumn get currency => text()();

  /// Denormalised sum of line items, in minor units. Stored for fast daily
  /// reports without re-joining every sale; recomputed and checked on write.
  IntColumn get totalMinor => integer().named('total_minor')();

  /// `paid` or `credit`. A `credit` sale spawns a row in [Debts].
  TextColumn get paymentStatus => text().named('payment_status')();
}

/// One line of a sale.
class SaleItems extends Table with SyncColumns {
  TextColumn get saleId => text().named('sale_id')();
  TextColumn get productId => text().named('product_id')();

  RealColumn get quantity => real()();

  /// Price AT THE TIME OF SALE. Snapshotted so changing a product's price later
  /// never rewrites past receipts/reports. See ARCHITECTURE.md §5.
  IntColumn get unitPriceMinor => integer().named('unit_price_minor')();
  IntColumn get lineTotalMinor => integer().named('line_total_minor')();
}

/// A debt owed by a customer — from a credit sale or entered manually.
class Debts extends Table with SyncColumns {
  TextColumn get customerId => text().named('customer_id')();

  /// Links back to the originating sale, if any.
  TextColumn get saleId => text().named('sale_id').nullable()();

  TextColumn get currency => text()();

  /// Original amount owed, in minor units. Immutable. The outstanding balance
  /// is DERIVED as principal minus the sum of [DebtPayments] — never stored —
  /// so two devices can only ever *add* payments and never corrupt a balance.
  IntColumn get principalMinor => integer().named('principal_minor')();

  IntColumn get incurredAt => integer().named('incurred_at')();
  IntColumn get dueDate => integer().named('due_date').nullable()();
  TextColumn get note => text().nullable()();
}

/// A payment made against a [Debts] row. Append-only by design.
class DebtPayments extends Table with SyncColumns {
  TextColumn get debtId => text().named('debt_id')();
  IntColumn get amountMinor => integer().named('amount_minor')();
  TextColumn get currency => text()();
  IntColumn get paidAt => integer().named('paid_at')();
}
