import 'package:flutter/material.dart';
import 'game_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/offline_queue.dart';
import 'caregiver_screen.dart';
import 'login_screen.dart';
import 'memory_game_screen.dart';
import 'pattern_game_screen.dart';
import 'progress_screen.dart';
import 'reminders_screen.dart';
import 'voice_assistant_screen.dart';
import 'attention_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.token,
  });

  final String userId;
  final String role;
  final String token;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? patient;
  Map<String, dynamic>? analyticsSummary;
  List<dynamic> gameAttempts = [];

  String? error;

  bool loading = true;
  bool syncing = false;
  bool analyticsLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.role == 'caregiver') {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    try {
      final profile = await ApiService.getMyPatient(widget.token);

      if (mounted) {
        setState(() {
          patient = profile;
          loading = false;
          error = null;
        });
      }

      final patientId = profile['patient_id']?.toString();
      if (patientId != null && patientId.isNotEmpty) {
        await _loadDashboardAnalytics(patientId);
      }

      _syncOfflineData();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadDashboardAnalytics(String patientId) async {
    if (mounted) {
      setState(() {
        analyticsLoading = true;
      });
    }

    try {
      final summary = await ApiService.getAnalyticsSummary(
        widget.token,
        patientId,
      );

      final attempts = await ApiService.getGameAttempts(
        widget.token,
        patientId,
      );

      if (mounted) {
        setState(() {
          analyticsSummary = summary;
          gameAttempts = attempts;
        });
      }
    } catch (_) {
      // Analytics should never prevent the home screen from loading.
      if (mounted) {
        setState(() {
          analyticsSummary = null;
          gameAttempts = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          analyticsLoading = false;
        });
      }
    }
  }

  double _gameAccuracy(String gameType) {
    final attempts = gameAttempts.where((attempt) {
      if (attempt is! Map) return false;
      return attempt['game_type']?.toString() == gameType;
    }).toList();

    if (attempts.isEmpty) return 0;

    double total = 0;
    int count = 0;

    for (final attempt in attempts) {
      final accuracy = attempt['accuracy'];
      if (accuracy is num) {
        total += accuracy.toDouble();
        count++;
      }
    }

    if (count == 0) return 0;
    return (total / count).clamp(0, 100);
  }

  int _completedActivities() {
    final value = analyticsSummary?['completed_sessions'];
    return value is num ? value.toInt() : gameAttempts.length;
  }

  String _currentDifficulty() {
    final value = analyticsSummary?['current_difficulty'];
    if (value == null || value.toString().isEmpty) return 'Starting';

    final difficulty = value.toString();
    return difficulty[0].toUpperCase() + difficulty.substring(1);
  }

  String _trendText() {
    final value = analyticsSummary?['trend']?.toString();
    switch (value) {
      case 'improving':
        return 'Improving';
      case 'declining':
        return 'Needs more practice';
      case 'stable':
        return 'Stable';
      default:
        return 'Keep practicing';
    }
  }

  Future<void> _syncOfflineData() async {
    if (mounted) {
      setState(() {
        syncing = true;
      });
    }

    try {
      await OfflineQueue.sync(widget.token);
    } catch (_) {
      // Offline synchronization can safely fail.
      // Pending data will be retried later.
    }

    if (mounted) {
      setState(() {
        syncing = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout(widget.token);
    } catch (_) {}

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

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF20242C),
        elevation: 0,
        title: const Text(
          'Cognitive Care',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          if (syncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : error != null
                ? _error()
                : widget.role == 'caregiver'
                    ? CaregiverScreen(
                        token: widget.token,
                      )
                    : _elderlyHome(),
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: Icon(
                Icons.cloud_off,
                size: 56,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load your profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                    error = null;
                  });

                  _load();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: Text(
                    'TRY AGAIN',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _elderlyHome() {
    final patientId = patient!['patient_id'] as String;

    final name = patient!['name']?.toString() ?? 'Friend';

    final language =
        patient!['language']?.toString() ?? 'English';

    final age = patient!['age']?.toString() ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          18,
          20,
          32,
        ),
        children: [
          _welcomeCard(
            name: name,
            language: language,
            age: age,
          ),

          const SizedBox(height: 22),

          _sectionTitle(
            title: 'Today\'s Activities',
            subtitle:
                'Choose one gentle activity to begin.',
          ),

          const SizedBox(height: 14),

          // MEMORY GAME
          _gameCard(
            title: 'Memory Game',
            subtitle:
                'Remember familiar objects and improve recall.',
            icon: Icons.psychology,
            iconBackground: const Color(0xFFE8EAFE),
            iconColor: const Color(0xFF4B4FC7),
            onTap: () {
              _open(
                MemoryGameScreen(
                  patientId: patientId,
                  token: widget.token,
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // ATTENTION GAME
          _gameCard(
            title: 'Attention Game',
            subtitle:
                'Find and count the correct symbols.',
            icon: Icons.center_focus_strong,
            iconBackground: const Color(0xFFE2F5F1),
            iconColor: const Color(0xFF168B76),
            onTap: () {
              _open(
                AttentionGameScreen(
  patientId: patientId,
  token: widget.token,
),
              );
            },
          ),

          const SizedBox(height: 14),

          // PATTERN GAME
          _gameCard(
            title: 'Pattern Game',
            subtitle:
                'Complete simple patterns and sequences.',
            icon: Icons.extension,
            iconBackground: const Color(0xFFFFEBDD),
            iconColor: const Color(0xFFE46C27),
            onTap: () {
              _open(
                PatternGameScreen(
                  patientId: patientId,
                  token: widget.token,
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // PROGRESS
          _gameCard(
            title: 'My Progress',
            subtitle:
                'See your memory, attention and pattern progress.',
            icon: Icons.trending_up,
            iconBackground: const Color(0xFFE7F5E9),
            iconColor: const Color(0xFF3E8E4E),
            onTap: () {
              _open(
                ProgressScreen(
                  patientId: patientId,
                  token: widget.token,
                ),
              );
            },
          ),

          const SizedBox(height: 26),

          _sectionTitle(
            title: 'Daily Support',
            subtitle:
                'Everything you need for today.',
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _supportCard(
                  title: 'Reminders',
                  subtitle: 'Medicine & activities',
                  icon: Icons.notifications_active,
                  iconColor: const Color(0xFF7A43B6),
                  backgroundColor:
                      const Color(0xFFF0E7F8),
                  onTap: () {
                    _open(
                      RemindersScreen(
                        token: widget.token,
                        patientId: patientId,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _supportCard(
                  title: 'Voice Help',
                  subtitle: 'Talk to your assistant',
                  icon: Icons.mic,
                  iconColor: const Color(0xFF2773B9),
                  backgroundColor:
                      const Color(0xFFE5F0FA),
                  onTap: () {
                    _open(
                      VoiceAssistantScreen(
                        token: widget.token,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          _progressCard(
            onTap: () {
              _open(
                ProgressScreen(
                  patientId: patientId,
                  token: widget.token,
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          _languageCard(language),

          const SizedBox(height: 18),

          _encouragementCard(),
        ],
      ),
    );
  }

  Widget _welcomeCard({
    required String name,
    required String language,
    required String age,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4B4FC7),
            Color(0xFF6D70D8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 42,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good day!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                Row(
                  children: [
                    const Icon(
                      Icons.language,
                      size: 17,
                      color: Colors.white70,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      language,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),

                    if (age.isNotEmpty) ...[
                      const SizedBox(width: 14),

                      const Icon(
                        Icons.cake,
                        size: 16,
                        color: Colors.white70,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        age,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Color(0xFF20242C),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _gameCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  size: 38,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 17),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 150,
          ),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCard({
    required VoidCallback onTap,
  }) {
    final memory = _gameAccuracy('memory') / 100;
    final attention = _gameAccuracy('attention') / 100;
    final pattern = _gameAccuracy('pattern') / 100;
    final completed = _completedActivities();
    final trend = _trendText();
    final difficulty = _currentDifficulty();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: analyticsLoading
              ? const SizedBox(
                  height: 170,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.insights,
                          size: 27,
                          color: Color(0xFF4B4FC7),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Your Progress',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _progressRow(
                      'Memory',
                      memory,
                      const Color(0xFF4B4FC7),
                    ),
                    const SizedBox(height: 13),
                    _progressRow(
                      'Attention',
                      attention,
                      const Color(0xFF168B76),
                    ),
                    const SizedBox(height: 13),
                    _progressRow(
                      'Pattern',
                      pattern,
                      const Color(0xFFE46C27),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _dashboardStat(
                            Icons.check_circle_outline,
                            '$completed',
                            'Activities',
                          ),
                        ),
                        Expanded(
                          child: _dashboardStat(
                            Icons.trending_up,
                            trend,
                            'Trend',
                          ),
                        ),
                        Expanded(
                          child: _dashboardStat(
                            Icons.speed,
                            difficulty,
                            'Level',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _dashboardStat(
    IconData icon,
    String value,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
    String label,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _languageCard(String language) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3E8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.translate,
              color: Color(0xFF4B7F3D),
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Language',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  language,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _encouragementCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFE3B0),
        ),
      ),
      child: const Row(
        children: [
          Text(
            '🌱',
            style: TextStyle(
              fontSize: 35,
            ),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Text(
              'Every small activity counts. Keep going at your own pace.',
              style: TextStyle(
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}