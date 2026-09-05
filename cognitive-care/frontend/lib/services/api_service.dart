import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://sih2026-gh31.onrender.com';

  // ============================================================
  // GENERIC REQUEST
  // ============================================================

  static Future<dynamic> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await http.get(
            uri,
            headers: headers,
          );
          break;

        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;

        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;

        case 'DELETE':
          response = await http.delete(
            uri,
            headers: headers,
          );
          break;

        default:
          throw ArgumentError(
            'Unsupported request method: $method',
          );
      }
    } catch (error) {
      throw Exception(
        'Unable to connect to SmiritiSarthi server.',
      );
    }

    if (response.statusCode == 204) {
      return null;
    }

    dynamic decoded;

    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{
        'detail': response.body,
      };
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    final detail =
        decoded is Map ? decoded['detail'] : null;

    throw Exception(
      detail?.toString() ??
          'Request failed (${response.statusCode})',
    );
  }

  // ============================================================
  // AUTH
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required int age,
    required String language,
  }) async {
    final response = await _request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'age': age,
        'language': language,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await _request(
      'POST',
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<void> logout(
    String token,
  ) async {
    await _request(
      'POST',
      '/auth/logout',
      token: token,
    );
  }

  // ============================================================
  // PATIENT
  // ============================================================

  static Future<Map<String, dynamic>> getMyPatient(
    String token,
  ) async {
    final response = await _request(
      'GET',
      '/patients/me',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // GAMES
  // ============================================================

  static Future<List<dynamic>> getGames(
    String token,
  ) async {
    final response = await _request(
      'GET',
      '/games',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  // ============================================================
  // START GAME
  // ============================================================

  static Future<Map<String, dynamic>> startGame({
    required String token,
    required String patientId,
    required String gameType,
    required int difficulty,
  }) async {
    final response = await _request(
      'POST',
      '/$gameType-game/start',
      token: token,
      body: {
        'patient_id': patientId,
        'difficulty': difficulty,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // SUBMIT GAME
  // ============================================================

  static Future<Map<String, dynamic>> submitGame({
    required String token,
    required String patientId,
    required String gameType,
    required String sessionId,
    required double reactionTime,
    required int hintsUsed,
    required dynamic answer,
  }) async {
    final body = <String, dynamic>{
      'patient_id': patientId,
      'game_session_id': sessionId,
      'reaction_time': reactionTime,
      'hints_used': hintsUsed,
    };

    if (gameType == 'memory') {
      body['selected_objects'] = answer;
    } else {
      body['answer'] = answer;
    }

    final response = await _request(
      'POST',
      '/$gameType-game/submit',
      token: token,
      body: body,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // MEMORY GAME
  // ============================================================

  static Future<Map<String, dynamic>> startMemoryGame({
    required String token,
    required String patientId,
    required int difficulty,
  }) async {
    return startGame(
      token: token,
      patientId: patientId,
      gameType: 'memory',
      difficulty: difficulty,
    );
  }

  static Future<Map<String, dynamic>> submitMemoryGame({
    required String token,
    required String patientId,
    required String gameSessionId,
    required List<String> selectedObjects,
    required double reactionTime,
    int hintsUsed = 0,
  }) async {
    return submitGame(
      token: token,
      patientId: patientId,
      gameType: 'memory',
      sessionId: gameSessionId,
      reactionTime: reactionTime,
      hintsUsed: hintsUsed,
      answer: selectedObjects,
    );
  }

  // ============================================================
  // PATTERN GAME
  // ============================================================

  static Future<Map<String, dynamic>> startPatternGame({
    required String token,
    required String patientId,
    required int difficulty,
  }) async {
    return startGame(
      token: token,
      patientId: patientId,
      gameType: 'pattern',
      difficulty: difficulty,
    );
  }

  // ============================================================
  // ATTENTION GAME
  // ============================================================

  static Future<Map<String, dynamic>> startAttentionGame({
    required String token,
    required String patientId,
    required int difficulty,
  }) async {
    return startGame(
      token: token,
      patientId: patientId,
      gameType: 'attention',
      difficulty: difficulty,
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  static Future<Map<String, dynamic>> getPatientPerformance(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/performance',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> analytics(
    String token,
    String patientId,
  ) async {
    return getPatientPerformance(
      token,
      patientId,
    );
  }

  static Future<Map<String, dynamic>> getAnalyticsSummary(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/analytics/patient/$patientId/summary',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getAnalyticsTrends(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/analytics/patient/$patientId/trends',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<List<dynamic>> getGameAttempts(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/analytics/patient/$patientId/games',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  // ============================================================
  // COGNITIVE PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> getCognitiveProfile(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/cognitive-profile',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // PERSONALIZATION
  // ============================================================

  static Future<Map<String, dynamic>> getNextSession(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/next-session',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // REMINDERS
  // ============================================================

  static Future<List<dynamic>> reminders(
    String token, {
    String? patientId,
  }) async {
    final suffix = patientId == null
        ? ''
        : '?patient_id=${Uri.encodeQueryComponent(patientId)}';

    final response = await _request(
      'GET',
      '/reminders$suffix',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  static Future<void> createReminder(
    String token,
    Map<String, dynamic> reminder,
  ) async {
    await _request(
      'POST',
      '/reminders',
      token: token,
      body: reminder,
    );
  }

  static Future<void> updateReminder(
    String token,
    String id,
    Map<String, dynamic> changes,
  ) async {
    await _request(
      'PUT',
      '/reminders/$id',
      token: token,
      body: changes,
    );
  }

  static Future<void> deleteReminder(
    String token,
    String id,
  ) async {
    await _request(
      'DELETE',
      '/reminders/$id',
      token: token,
    );
  }

  // ============================================================
  // CAREGIVER
  // ============================================================

  static Future<List<dynamic>> caregiverPatients(
    String token,
  ) async {
    final response = await _request(
      'GET',
      '/caregiver/patients',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  static Future<List<dynamic>> caregiverRequests(
    String token,
  ) async {
    final response = await _request(
      'GET',
      '/caregiver/requests',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  static Future<List<dynamic>> caregiverMyRequests(
    String token,
  ) async {
    final response = await _request(
      'GET',
      '/caregiver/my-requests',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> requestCaregiverLink({
    required String token,
    required String patientId,
    required String relationship,
  }) async {
    final response = await _request(
      'POST',
      '/caregiver/links',
      token: token,
      body: {
        'patient_id': patientId,
        'relationship': relationship,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> acceptCaregiverLink({
    required String token,
    required String linkId,
  }) async {
    final response = await _request(
      'PUT',
      '/caregiver/links/$linkId/accept',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // VOICE
  // ============================================================

  static Future<Map<String, dynamic>> voiceCommand(
    String token,
    String text, {
    String language = 'en',
    List<Map<String, String>> history = const [],
  }) async {
    final response = await _request(
      'POST',
      '/voice/command',
      token: token,
      body: {
        'text': text,
        'language': language,
        'history': history,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // MEMORY MOMENTS
  // ============================================================

  static Future<Map<String, dynamic>> createMemory({
    required String token,
    required String patientId,
    required String title,
    String description = '',
    List<String> people = const [],
    String place = '',
    int? year,
    List<String> tags = const [],
    int priority = 0,
  }) async {
    final response = await _request(
      'POST',
      '/memories',
      token: token,
      body: {
        'patient_id': patientId,
        'title': title,
        'description': description,
        'people': people,
        'place': place,
        'year': year,
        'tags': tags,
        'priority': priority,
      },
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<List<dynamic>> listMemories(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/memories?patient_id=$patientId',
      token: token,
    );

    return List<dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getTodayMemory(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/memories/today?patient_id=$patientId',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getMemory(
    String token,
    String memoryId,
  ) async {
    final response = await _request(
      'GET',
      '/memories/$memoryId',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> updateMemory({
    required String token,
    required String memoryId,
    String? title,
    String? description,
    List<String>? people,
    String? place,
    int? year,
    List<String>? tags,
    int? priority,
    bool? active,
  }) async {
    final body = <String, dynamic>{};

    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (people != null) body['people'] = people;
    if (place != null) body['place'] = place;
    if (year != null) body['year'] = year;
    if (tags != null) body['tags'] = tags;
    if (priority != null) body['priority'] = priority;
    if (active != null) body['active'] = active;

    final response = await _request(
      'PUT',
      '/memories/$memoryId',
      token: token,
      body: body,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> deleteMemory(
    String token,
    String memoryId,
  ) async {
    final response = await _request(
      'DELETE',
      '/memories/$memoryId',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> memoryInteraction({
    required String token,
    required String memoryId,
    required String action,
  }) async {
    final response = await _request(
      'POST',
      '/memories/$memoryId/interact?action=$action',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // OFFLINE SYNC
  // ============================================================

  static Future<Map<String, dynamic>> syncAttempt(
    String token,
    Map<String, dynamic> event,
  ) async {
    final response = await _request(
      'POST',
      '/sync/attempts',
      token: token,
      body: event,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> syncReminder(
    String token,
    Map<String, dynamic> event,
  ) async {
    final response = await _request(
      'POST',
      '/sync/reminders',
      token: token,
      body: event,
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // CONTENT
  // ============================================================

  static Future<Map<String, dynamic>> getLanguages() async {
    final response = await _request(
      'GET',
      '/content/languages',
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getContentPack(
    String region,
  ) async {
    final response = await _request(
      'GET',
      '/content/packs/${Uri.encodeComponent(region)}',
    );

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // COMPLETE PLATFORM FEATURES
  // ============================================================

  static Future<Map<String, dynamic>> getDailyActivity(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/daily-activity',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getAlerts(
    String token,
    String patientId, {
    bool caregiver = false,
  }) async {
    final path = caregiver
        ? '/caregiver/patients/$patientId/alerts'
        : '/patients/$patientId/alerts';

    final response = await _request(
      'GET',
      path,
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getPreferences(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/preferences',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> updatePreferences(
    String token,
    String patientId,
    Map<String, dynamic> preferences,
  ) async {
    final response = await _request(
      'PUT',
      '/patients/$patientId/preferences',
      token: token,
      body: preferences,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getNotificationFeed(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/notification-feed',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getCurrentUser(
    String token,
  ) async {
    final response = await _request(
      'GET',
      '/auth/me',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> getDifficultyRecommendation(
    String token,
    String patientId,
  ) async {
    final response = await _request(
      'GET',
      '/patients/$patientId/difficulty-recommendation',
      token: token,
    );

    return Map<String, dynamic>.from(response);
  }
}