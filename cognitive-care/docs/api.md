# API

All endpoints except registration, login, root, and content discovery require `Authorization: Bearer <JWT>`.

| Area | Endpoints |
| --- | --- |
| Authentication | `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` |
| Patient | `GET /patients/me`, `GET /patients/{id}` |
| Games | `POST /memory-game/start|submit`, `POST /pattern-game/start|submit`, `POST /attention-game/start|submit` |
| Analytics | `GET /analytics/patient/{id}`, `/summary`, `/trends`, `/games`; `GET /ai/profile/{id}`, `POST /ai/recommendation/{id}` |
| Caregiver | `POST /caregiver/links`, `GET /caregiver/requests`, `PUT /caregiver/links/{id}/accept`, `GET /caregiver/patients` |
| Reminders | `GET|POST /reminders`, `PUT|DELETE /reminders/{id}` |
| Sync | `POST /sync/attempts`, `POST /sync/reminders` |
| Content/voice | `GET /content/languages`, `GET /content/packs/{region}`, `POST /voice/command` |

Game start responses expose only the challenge needed by the player. Correct answers remain in the session and are scored server-side on submit. `patient_id` is always authorized server-side; it is never trusted merely because the client supplied it.
