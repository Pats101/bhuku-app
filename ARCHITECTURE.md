# Architecture — Inventory & Debt Tracking System

**Audience:** informal traders in Zimbabwe (tuckshops, market vendors, salons, small wholesalers).
**Reality we design for:** unreliable internet, low-end Android, low technical literacy, USD + ZiG, informal bookkeeping.

> Design rule for the whole system: **the phone works perfectly with the network unplugged forever.** The server is a sync target and backup, never a dependency for daily use.

---

## 1. Principles (and what they forbid)

| Principle | What it allows | What it forbids |
|---|---|---|
| Offline-first | All reads/writes hit local SQLite. Sync is a background concern. | No feature may block on a network call. No "loading spinner to view my own stock." |
| Phone is source of truth | Server reconciles what phones send. | Server never invents business data; no server-side IDs for business rows. |
| Simple over clever | Last-write-wins per row. | No CRDTs, no operational transforms, no event sourcing for MVP. |
| Money is exact | Integer minor units + currency code. | No floats for money, anywhere, ever. |
| Low data usage | Delta sync via change log. | No full-table dumps. No syncing images in MVP. |

---

## 2. System topology

```
┌─────────────────────────────┐         ┌──────────────────────────────┐
│      Android device          │         │        Cloud (Docker)         │
│                              │         │                               │
│  Flutter UI (Riverpod)       │         │  FastAPI (modular monolith)   │
│       │                      │         │      │                        │
│  Repositories                │  HTTPS  │  Sync + feature routers       │
│       │                      │  REST   │      │                        │
│  Drift / SQLite  ◄───────────┼────────►│  PostgreSQL                   │
│  (source of truth)           │ delta   │  (backup + multi-device merge)│
│                              │  sync   │                               │
│  Supabase session cache      │         │  Supabase Auth (JWT verify)   │
└─────────────────────────────┘         └──────────────────────────────┘
```

- **Auth:** Supabase issues JWTs. FastAPI verifies the JWT signature (Supabase JWKS); it does not own passwords.
- **Sync transport:** plain REST (`/sync/push`, `/sync/pull`). No websockets in MVP — they don't survive flaky 2G.

---

## 3. Repository structure

### Flutter (feature-first, clean architecture)

```
lib/
  core/
    db/            # Drift database, tables, DAOs
    money/         # Money value type, currency enum, formatting
    sync/          # SyncEngine, change-log queue, conflict policy
    network/       # Dio client, auth interceptor, connectivity
    error/         # Failure types, Result<T>
    di/            # Riverpod providers (composition root)
  features/
    auth/
      data/        # repository impl, remote/local data sources
      domain/      # entities, repository interface, use cases
      presentation/# screens, widgets, Riverpod controllers
    inventory/     # same data/domain/presentation triad
    sales/
    debts/
    reports/
  app.dart         # router, theme, root
  main.dart
```

Every feature is the **same three layers**. `inventory` is the reference implementation; the others are copies of its shape. This is the single most important thing for maintainability and onboarding.

### FastAPI (modular monolith — split into services later only if needed)

```
app/
  core/
    config.py        # pydantic-settings, env-driven
    security.py      # Supabase JWT verification dependency
    db.py            # async SQLAlchemy session
  modules/
    inventory/       # router.py, schemas.py, models.py, service.py, repository.py
    sales/
    debts/
    sync/            # the push/pull endpoints — the heart of the backend
  main.py
tests/
Dockerfile
docker-compose.yml   # api + postgres
```

We start as a **monolith**, not microservices. With one developer and an MVP, microservices are pure operational cost. The module boundaries above mean we *can* extract a service later without a rewrite.

---

## 4. Money & currency

```dart
// Stored everywhere as: amountMinor (int) + currency (enum)
enum Currency { usd, zwg }          // ZiG ISO code is ZWG

class Money {
  final int amountMinor;            // cents. $1.50 -> 150
  final Currency currency;
}
```

- **Never** mix currencies in one arithmetic operation. A sale is in one currency; a debt is in one currency.
- ZiG is high-inflation, so amounts get large — `int` (64-bit) is required, not 32-bit.
- Display formatting is a UI concern, never stored. DB holds only `amount_minor` + `currency`.
- No FX conversion in MVP. If a trader sells in both currencies, those are separate transactions. (Conversion = a later feature with its own rate table.)

---

## 5. Data model

Every business table carries the **same sync columns**. Define them once, reuse everywhere.

```
id            TEXT/UUID   PRIMARY KEY   -- client-generated UUIDv4
shop_id       UUID                      -- tenant scope (= owner for MVP)
created_at    INTEGER (epoch ms, UTC)
updated_at    INTEGER (epoch ms, UTC)   -- bumped on every local write; drives LWW
deleted_at    INTEGER NULL              -- soft delete (sync-safe; never hard-delete)

-- LOCAL-ONLY columns (never sent to server, not present in Postgres):
is_dirty      INTEGER (0/1)             -- has unsynced local changes
last_synced_at INTEGER NULL
```

> **Client-generated UUIDs** are the linchpin. An offline phone must create a sale and the debt linked to it *with valid foreign keys*, before the server has ever seen either row.

### Tables

**products** (inventory)
```
id, shop_id, name, sku NULL, unit (e.g. 'each','kg'),
cost_price_minor, sell_price_minor, currency,
quantity (numeric — supports kg/litres), reorder_level,
+ sync columns
```

**customers** (debt ledger is per customer)
```
id, shop_id, name, phone NULL, note NULL, + sync columns
```

**sales**
```
id, shop_id, customer_id NULL,      -- null = walk-in cash sale
sold_at, currency,
total_minor,                        -- denormalized sum of items (audit + fast reports)
payment_status ('paid'|'credit'),   -- 'credit' creates a debt
+ sync columns
```

**sale_items**
```
id, sale_id (FK), product_id (FK),
quantity, unit_price_minor,         -- price AT TIME OF SALE (never re-derive from product)
line_total_minor,
+ sync columns
```

**debts** (one ledger entry per credit sale or manual debt)
```
id, shop_id, customer_id (FK), sale_id NULL (FK),
currency, principal_minor,          -- original amount owed
incurred_at, due_date NULL,         -- drives "overdue debts" on dashboard
note NULL,
+ sync columns
-- balance is DERIVED: principal_minor - sum(debt_payments)
```

**debt_payments**
```
id, shop_id, debt_id (FK), amount_minor, currency, paid_at, + sync columns
```

### Why these shapes

- **`unit_price_minor` snapshotted on `sale_items`:** if the trader changes a product's price tomorrow, *yesterday's receipts and reports must not change.* Reports are computed from snapshots, not live product prices.
- **Debt balance is derived, not stored:** storing a mutable balance invites two devices disagreeing on the same number. Instead we store immutable `principal` + immutable `payments`; balance = subtraction. Two devices can never corrupt it — they can only *add* payment rows, which merge cleanly.
- **`total_minor` on `sales` is denormalized** for fast daily reports without joining `sale_items` for every sale. It's an audit value, recomputed and checked on write.
- **No stock-movement ledger in MVP.** Stock is a single mutable `quantity` field, adjusted by sales and manual edits. A full movement ledger is correct but overengineered for v1 — noted as a fast-follow if traders need audit history.

### Stock & sync tension (the one sharp edge)

`products.quantity` is mutable and shared. Last-write-wins on quantity means: two devices selling offline could each decrement from 10 → 9, and after sync the server shows 9 instead of 8.

**MVP decision (deferred):** proceed **single-device-per-shop**, where this cannot happen, and keep the schema explicitly ready for the ledger upgrade. **Revisit before launch** once we know whether real shops share devices. The *correct* fix (a stock-movement ledger where each sale writes a `-1` delta that sums commutatively) is the planned multi-device upgrade — and our schema already isolates it: only `products.quantity` is affected, nothing else changes.

> **Schema-readiness requirement for this deferral:** sales already create the rows a ledger would need (each `sale_item` is effectively a `-quantity` delta). The upgrade is therefore additive: introduce a `stock_movements` table, backfill deltas from existing `sale_items` + manual adjustments, and switch `quantity` from a stored field to a derived `SUM`. No existing data is destroyed or migrated destructively. Keep this true as we build inventory & sales.

---

## 6. Sync engine

### Change tracking
Every local write sets `is_dirty = 1` and bumps `updated_at`. No separate change-log table — the dirty flag *is* the queue. Simpler, and self-healing (a row stays dirty until the server confirms it).

### Protocol (push then pull)

```
POST /sync/push        # send my dirty rows
  body:  { changes: { products: [...], sales: [...], ... } }   // only dirty rows, server-shaped
  resp:  { applied: [ids], conflicts: [{id, server_row}] }

POST /sync/pull        # get everything changed since my last pull
  body:  { since: <epoch ms cursor> }
  resp:  { changes: {...rows...}, server_time: <epoch ms> }    // new cursor
```

1. **Push:** send all `is_dirty` rows. Server applies LWW (see below), returns which were applied. Client clears `is_dirty` and sets `last_synced_at` for applied rows.
2. **Pull:** ask for everything with `updated_at > since`. Apply incoming rows locally (LWW). Store `server_time` as the new `since` cursor.
3. Order matters by FK dependency: **products & customers → sales → sale_items → debts → debt_payments.** Parents before children so foreign keys always resolve.

### Conflict resolution — Last Write Wins per row
On collision (same `id`, both sides changed), the row with the **greater `updated_at` wins**. Ties (equal timestamps) → server wins, deterministically.

- This is safe for the append-mostly tables (sales, payments) because they're rarely edited after creation.
- It's "good enough" for products/customers (rare concurrent edits in single-device reality).
- **Soft deletes propagate as data:** a delete is just a row with `deleted_at` set — it syncs and wins by LWW like any other change. Never hard-delete, or the deletion can't travel.

### Clock safety
Cheap Android clocks drift. We don't trust device time for ordering across devices — the **pull cursor uses server time**, and `updated_at` is primarily an intra-device ordering aid. For MVP single-device this is a non-issue; documented for the multi-device upgrade.

### Idempotency
Push is idempotent: re-sending an already-applied row (same id, same/older `updated_at`) is a no-op server-side. This means a dropped connection mid-sync is always safe to retry — critical on 2G.

---

## 7. Auth flow

1. App calls Supabase Auth — **phone number + OTP is the primary method** (traders have phone numbers, not emails; WhatsApp-based verification is a later enhancement). Returns JWT + refresh token.
2. Session cached locally; **app opens straight to data offline** using the cached session. Expired token ≠ locked out of your own data — you just can't sync until reconnected + refreshed.
3. Every API call sends `Authorization: Bearer <jwt>`.
4. FastAPI verifies the JWT against Supabase's public keys (JWKS), extracts `sub` → maps to `shop_id`. No password handling in our backend.

---

## 8. Build sequence

1. **Foundations** — Drift schema + `Money` type + sync columns + sync contract types. (no UI)
2. **Auth** — Supabase phone + OTP, offline session.
3. **Inventory** — first full vertical slice; the pattern every other feature copies.
4. **Sales** — depletes inventory.
5. **Debts** — credit sales + payments ledger + due dates.
6. **Dashboard** — home screen: today's sales, low stock, outstanding/overdue debt. Pure read-side over local data.
7. **Sync engine** — push/pull/LWW, against tables that now exist.
8. **Reports** — daily summary, on-device PDF export, WhatsApp/share-intent sharing.

Sync is *designed* at step 1 (schema), *built* at step 7 (after tables exist).

### Reports & sharing (offline-first)
- PDF generated **on-device** (Flutter `pdf` package) — works with no network.
- Sharing uses the **Android share intent** (`share_plus`) → WhatsApp, email, anything installed. No special WhatsApp integration needed for MVP.
- **Supabase Storage** is used only for *optional cloud backup* of exports — never on the daily-use path. The app never blocks on it.

### Deployment (MVP)
Railway or Render for the FastAPI container + managed Postgres. Keep infra minimal; revisit only when load demands it.

---

## 9. Explicit non-goals (MVP)
AI chatbot · marketplace · payroll · full accounting · POS hardware · blockchain · advanced analytics · FX conversion · multi-device concurrent stock · image sync.

## 10. Known limitations (documented, not bugs)
- Single-device-per-shop assumed for correct stock counts (see §5).
- No FX conversion between USD/ZiG.
- Device clock drift tolerated under single-device assumption (see §6).
```
