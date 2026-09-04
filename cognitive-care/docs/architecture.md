# Architecture

Flutter provides two role-aware experiences: a high-contrast elderly home with games and reminders, and a caregiver dashboard for consented links. FastAPI owns all scoring, authorization, recommendations, and synchronization. MongoDB stores users, patients, sessions, attempts, profiles, reminders, consent links, and idempotency events.

```text
Flutter (local preferences + pending event queue)
        | JWT
        v
FastAPI ── auth / games / reminders / analytics / caregiver / sync
        |                              |
        v                              v
MongoDB                         rule-based adaptation
                                      |
                            optional validated ML model
```

Every patient-scoped operation validates the JWT and then verifies that an elderly user owns the profile or that a caregiver has an active, patient-accepted link. Health-worker access is intentionally disabled until an explicit consent/facility assignment model is implemented.

Offline attempts use a generated `client_event_id`; the server persists that identifier and returns an already-synced result on retries. The app uses local preferences for the prototype queue. A production Android build should move the queue to a durable local database and schedule background retry work.
