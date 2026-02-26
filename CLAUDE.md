# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Getting Started (Read This First!)

**When starting a new session or receiving a task:**
1. **Check `.project/TODO.md`** - See current tasks, planned features, and completed work
2. **Check `.project/NOTES.md`** - Review saved ideas, prompts, and technical notes
3. **Check `.project/docs/`** - For detailed design docs and context (if applicable)

These files contain the current project state, plans, and saved prompts that guide development.

## Workflow

This project uses slash command-based development workflow:

| Command | Effect |
|---------|--------|
| **/organize** | Organize discussion into .project/ docs |
| **/proceed** | Start implementing first planned task |
| **/verify** | Build/lint/typecheck + verify implementation |
| **/next** | Implement next task |

See `.project/WORKFLOW.md` for full details.

## Build & Run Commands

### Backend (Python FastAPI)
```bash
# Start all services (DB, Redis, API, Celery)
docker-compose up -d

# Run migrations
docker-compose run --rm migrate

# Dev server only (without Docker)
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Run Alembic migrations manually
cd backend
alembic upgrade head
```

### Frontend (Flutter)
```bash
cd frontend

# Get dependencies
flutter pub get

# Generate l10n files
flutter gen-l10n

# Run on emulator/device
flutter run

# Analyze
flutter analyze

# Test
flutter test
```

### API Endpoints
- Health check: `GET http://localhost:8000/api/v1/health`
- Search: `GET http://localhost:8000/api/v1/search?q=query`

## Architecture

```
Flutter Mobile App (frontend/)
    ↓ REST API (HTTPS)
Python FastAPI Backend (backend/)
    ├── Aggregation Service (8 source adapters in parallel)
    ├── Name Matching Engine (CJK romanization + fuzzy)
    ├── Deduplication Service
    └── Recommendation Service
    ↓
PostgreSQL (data) + Redis (cache) + Celery (background jobs)
```

**8 Platforms:** YouTube, Spotify, NicoNico, SoundCloud, Bandcamp, VocaDB, MusicBrainz, Last.fm

## Key Files

| File | Role |
|------|------|
| `backend/app/main.py` | FastAPI app entry point |
| `backend/app/config.py` | App configuration (env vars) |
| `backend/app/db/session.py` | SQLAlchemy async session |
| `backend/app/models/` | ORM models (artist, track, user) |
| `backend/app/sources/base.py` | Source adapter abstract interface |
| `backend/app/api/v1/router.py` | API router |
| `backend/alembic/versions/001_initial_schema.py` | DB schema migration |
| `frontend/lib/main.dart` | Flutter app entry point |
| `frontend/lib/config/routes.dart` | GoRouter navigation |
| `frontend/lib/config/theme.dart` | Dark theme definition |
| `frontend/lib/core/di/service_locator.dart` | GetIt DI setup |
| `frontend/lib/core/network/api_client.dart` | Dio HTTP client |
| `frontend/lib/domain/entities/` | Business entities |
| `frontend/lib/presentation/screens/` | UI screens |
| `frontend/lib/playback/playback_manager.dart` | Multi-platform playback routing |
| `docker-compose.yml` | Docker services config |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| State Management | flutter_bloc |
| Backend | Python FastAPI |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| Task Queue | Celery |
| Container | Docker Compose |
