# SIH demo flow

1. Start MongoDB-backed API: `cd backend; uvicorn app.main:app --reload`.
2. Run Flutter with the correct reachable backend: `flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:8000`.
3. Register an elderly account (age and language are saved into its automatic patient profile).
4. Play Memory, Pattern, and Attention activities; show server-generated score, profile, analytics, and next rule-based recommendation.
5. Add a reminder and mark it done.
6. Register a caregiver, create a link request, accept it from the elderly account, then show the caregiver dashboard.
7. Disable connectivity after a game submission; show its local-success message. Reopen the app online to sync it.

The demo must describe outputs as game-performance and engagement data, never as dementia diagnosis or progression.
