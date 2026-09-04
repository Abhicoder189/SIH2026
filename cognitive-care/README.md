# Cognitive Care — SIH 2026 PS 26003

An elderly-friendly cognitive-gaming and memory-assistance prototype for the North Eastern Region. It provides three server-scored games, rule-based personalization, reminders, consented caregiver visibility, regional content architecture, text-first voice fallback, and offline attempt synchronization.

It is **not** a diagnostic tool and does not claim to detect or predict dementia.

## Run

1. Copy `backend/.env.example` to `backend/.env`, then provide a MongoDB URI, database name, and a new long JWT secret.
2. `cd backend; python -m venv .venv; .venv\Scripts\activate; pip install -r requirements.txt; uvicorn app.main:app --reload`
3. `cd frontend; flutter pub get; flutter run --dart-define=API_BASE_URL=http://<reachable-host>:8000`

Run backend core tests with `cd backend; python -m unittest discover -s tests`. Run Flutter checks with `cd frontend; flutter analyze; flutter test`.

Optional safe demo data: set a non-production `DEMO_PASSWORD`, then run `cd backend; python seed_demo.py`. The seed script uses an `.invalid` email address and never runs automatically.

See [architecture](docs/architecture.md), [API](docs/api.md), [demo script](docs/demo.md), and [references](docs/references.md).
