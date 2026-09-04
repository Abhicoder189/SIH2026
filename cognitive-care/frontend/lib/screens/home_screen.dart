import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

import 'attention_game_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'cognitive_dashboard_screen.dart';
import 'login_screen.dart';
import 'memory_game_screen.dart';
import 'notification_feed_screen.dart';
import 'pattern_game_screen.dart';
import 'preferences_screen.dart';
import 'reminders_screen.dart';
import 'voice_assistant_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final String role;
  final String token;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.token,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _patient = {};
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _nextSession = {};
  Map<String, dynamic> _notifications = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.role == 'caregiver') {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final patient = await ApiService.getMyPatient(widget.token);

      final patientId =
          patient['id']?.toString() ??
          patient['patient_id']?.toString() ??
          patient['_id']?.toString();

      if (patientId == null || patientId.isEmpty) {
        throw Exception('Patient profile not found.');
      }

      final results = await Future.wait([
        ApiService.getAnalyticsSummary(
          widget.token,
          patientId,
        ),
        ApiService.getNextSession(
          widget.token,
          patientId,
        ),
        ApiService.getNotificationFeed(
          widget.token,
          patientId,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _patient = Map<String, dynamic>.from(patient);
        _summary = Map<String, dynamic>.from(results[0]);
        _nextSession = Map<String, dynamic>.from(results[1]);
        _notifications = Map<String, dynamic>.from(results[2]);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst(
              'Exception: ',
              '',
            );
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout(widget.token);
    } catch (_) {
      // Local logout should still happen even if the server request fails.
    }

    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  double _accuracy() {
    /*
     * Backend analytics returns:
     *
     * average_accuracy
     *
     * and game-specific analytics contain:
     *
     * average_accuracy
     */

    final byGameType = _summary['by_game_type'];

    if (byGameType is Map && byGameType.isNotEmpty) {
      double total = 0;
      int count = 0;

      for (final value in byGameType.values) {
        if (value is Map) {
          final accuracy =
              value['average_accuracy'] ?? value['accuracy'];

          if (accuracy is num) {
            total += accuracy.toDouble();
            count++;
          }
        }
      }

      if (count > 0) {
        return total / count;
      }
    }

    final average = _summary['average_accuracy'];

    if (average is num) {
      return average.toDouble();
    }

    return 0;
  }

  String _recommendationText() {
    final recommendation = _nextSession['recommendation'];

    if (recommendation is Map) {
      final gameType =
          recommendation['game_type']?.toString() ??
          'activity';

      final difficulty =
          recommendation['difficulty']?.toString() ??
          '1';

      final reason =
          recommendation['reason']?.toString();

      final formattedGameType = _formatGameType(gameType);

      if (reason != null && reason.trim().isNotEmpty) {
        return '$formattedGameType • Difficulty $difficulty\n$reason';
      }

      return '$formattedGameType • Difficulty $difficulty';
    }

    /*
     * Some backend versions may return the recommendation
     * fields directly instead of nesting them.
     */
    final gameType =
        _nextSession['game_type']?.toString();

    final difficulty =
        _nextSession['difficulty']?.toString();

    final reason =
        _nextSession['reason']?.toString();

    if (gameType != null && gameType.isNotEmpty) {
      final formattedGameType =
          _formatGameType(gameType);

      final difficultyText =
          difficulty != null && difficulty.isNotEmpty
              ? ' • Difficulty $difficulty'
              : '';

      if (reason != null && reason.trim().isNotEmpty) {
        return '$formattedGameType$difficultyText\n$reason';
      }

      return '$formattedGameType$difficultyText';
    }

    if (recommendation != null) {
      final text = recommendation.toString().trim();

      if (text.isNotEmpty && text != '{}') {
        return text;
      }
    }

    return 'Keep practicing regularly to maintain your cognitive engagement.';
  }

  String _formatGameType(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'memory':
        return 'Memory Game';

      case 'attention':
        return 'Attention Game';

      case 'pattern':
        return 'Pattern Game';

      default:
        if (gameType.isEmpty) {
          return 'Activity';
        }

        return gameType[0].toUpperCase() +
            gameType.substring(1);
    }
  }

  String _patientId() {
    return _patient['id']?.toString() ??
        _patient['patient_id']?.toString() ??
        _patient['_id']?.toString() ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    // Caregiver gets the dedicated caregiver dashboard.
    if (widget.role == 'caregiver') {
      return CaregiverDashboardScreen(
        token: widget.token,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'SmiritiSarthi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _errorBody()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _welcome(),

          const SizedBox(height: 18),

          _recommendationCard(),

          const SizedBox(height: 24),

          _title('Cognitive Games'),

          const SizedBox(height: 12),

          _card(
            title: 'Memory Game',
            subtitle: 'Train recall and memory',
            icon: Icons.psychology,
            onTap: () {
              _open(
                MemoryGameScreen(
                  token: widget.token,
                  patientId: _patientId(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _card(
            title: 'Attention Game',
            subtitle: 'Improve focus and concentration',
            icon: Icons.center_focus_strong,
            onTap: () {
              _open(
                AttentionGameScreen(
                  token: widget.token,
                  patientId: _patientId(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _card(
            title: 'Pattern Game',
            subtitle: 'Practice pattern recognition',
            icon: Icons.extension,
            onTap: () {
              _open(
                PatternGameScreen(
                  token: widget.token,
                  patientId: _patientId(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          _title('Daily Support'),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _small(
                  'Reminders',
                  Icons.alarm,
                  () {
                    _open(
                      RemindersScreen(
                        token: widget.token,
                        patientId: _patientId(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _small(
                  'Voice Help',
                  Icons.mic,
                  () {
                    _open(
                      VoiceAssistantScreen(
                        token: widget.token,
                        patientId: _patientId(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _small(
                  'My Progress',
                  Icons.insights,
                  () {
                    _open(
                      CognitiveDashboardScreen(
                        token: widget.token,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _small(
                  'Settings',
                  Icons.settings,
                  () {
                    _open(
                      PreferencesScreen(
                        token: widget.token,
                        patientId: _patientId(),
                        language:
                            _patient['language']?.toString() ??
                            'English',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _title('Your Progress'),

          const SizedBox(height: 12),

          _progress(),

          const SizedBox(height: 20),

          if (_notifications.isNotEmpty)
            _notificationSummary(),

          const SizedBox(height: 20),

          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This application is designed for cognitive '
                'engagement and personalization. It does not '
                'diagnose or treat dementia or any medical condition.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    final name = _patient['name']?.toString() ??
        _patient['full_name']?.toString() ??
        'there';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              child: Icon(
                Icons.person,
                size: 32,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $name!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Let’s keep your mind active today.',
                    style: TextStyle(
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              child: Icon(Icons.auto_awesome),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today’s Recommendation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _recommendationText(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                child: Icon(
                  icon,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _small(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 10,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 30,
              ),

              const SizedBox(height: 8),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    final accuracy =
        _accuracy().clamp(0, 100).toDouble();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overall Accuracy',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  '${accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: accuracy / 100,
                minHeight: 12,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Your progress is based on recent cognitive game sessions.',
              style: TextStyle(
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationSummary() {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.notifications),
        ),

        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: const Text(
          'You have recent updates and reminders.',
        ),

        trailing: const Icon(Icons.chevron_right),

        onTap: () {
          _open(
            NotificationFeedScreen(
              token: widget.token,
              patientId: _patientId(),
            ),
          );
        },
      ),
    );
  }
}