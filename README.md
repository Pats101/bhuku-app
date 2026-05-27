# Bhuku

> _Bhuku_ — "book" in Shona. The trader's ledger, made offline-first and unloseable.

An offline-first inventory & debt tracking app for informal traders in Zimbabwe
(tuckshops, market vendors, salons, small wholesalers). Works fully with no
internet; syncs in the background when a connection appears.

- **Repo:** https://github.com/Pats101/bhuku-app
- **Architecture & decisions:** see [`ARCHITECTURE.md`](./ARCHITECTURE.md)

## Stack

| Layer | Tech |
|---|---|
| Mobile | Flutter · Riverpod · Drift/SQLite |
| Backend | FastAPI · SQLAlchemy (async) · Alembic |
| Database | PostgreSQL |
| Auth | Supabase (phone + OTP) |
| Deploy | Docker → Railway/Render |

## Repository layout

```
mobile/    Flutter app (feature-first clean architecture)
  lib/core/        money, db (Drift), sync contract, network, DI — the spine
backend/   FastAPI modular monolith
  app/core/        config, db, JWT security, shared sync base model
  app/modules/     inventory, sales, debts, sync
ARCHITECTURE.md   System design, data model, sync protocol
```

## Backend — quick start

```bash
cd backend
cp .env.example .env            # set SUPABASE_JWT_SECRET from Supabase dashboard
docker compose up --build       # API on :8000, Postgres on :5432

# create the schema (after compose is up, in another shell):
alembic revision --autogenerate -m "initial schema"
alembic upgrade head

# tests (in-memory SQLite, no Postgres needed):
pip install -r requirements.txt
pytest
```

Health check: `GET http://localhost:8000/health` → `{"status":"ok"}`.

## Mobile — quick start

```bash
cd mobile
flutter pub get
dart run build_runner build     # generates Drift's database.g.dart
flutter test                    # runs the Money unit tests

flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000   # host localhost from emulator
```

## Status

**Foundations complete** — money/currency types, Drift schema with sync columns,
sync protocol (client DTOs + working server push/pull with last-write-wins),
auth wiring, DI, Docker, Alembic. Features come next per the build sequence in
`ARCHITECTURE.md §8`: Auth → Inventory → Sales → Debts → Dashboard → Sync engine
→ Reports.
