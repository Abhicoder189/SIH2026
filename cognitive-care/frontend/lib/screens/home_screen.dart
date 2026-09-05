import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

import 'attention_game_screen.dart';
import 'cognitive_dashboard_screen.dart';
import 'login_screen.dart';
import 'memory_game_screen.dart';
import 'memory_moment_screen.dart';
import 'journey_assist_screen.dart';
import 'family_recognition_screen.dart';
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

  // Pending caregiver requests for the elderly user.
  List<dynamic> _caregiverRequests = [];

  // Keeps track of requests currently being accepted.
  final Set<String> _acceptingCaregiverRequests = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.role == 'caregiver') {
      if (!mounted) {
        return;
      }

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
      final patient = await ApiService.getMyPatient(
        widget.token,
      );

      final patientId =
          patient['id']?.toString() ??
          patient['patient_id']?.toString() ??
          patient['_id']?.toString();

      if (patientId == null || patientId.isEmpty) {
        throw Exception(
          'Patient profile not found.',
        );
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
        ApiService.caregiverRequests(
          widget.token,
        ),
      ]);

      if (!mounted) {
        return;
      }

     setState(() {
  _patient = Map<String, dynamic>.from(
    patient,
  );

  _summary = Map<String, dynamic>.from(
    results[0] as Map,
  );

  _nextSession = Map<String, dynamic>.from(
    results[1] as Map,
  );

  _notifications = Map<String, dynamic>.from(
    results[2] as Map,
  );

  _caregiverRequests = results[3] is List
      ? List<dynamic>.from(
          results[3] as List,
        )
      : [];

  _loading = false;
});
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );

        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout(
        widget.token,
      );
    } catch (_) {
      // Local logout must still work if server
      // is unavailable.
    }

    await AuthService.logout();

    if (!mounted) {
      return;
    }

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

  String _patientId() {
    return _patient['id']?.toString() ??
        _patient['patient_id']?.toString() ??
        _patient['_id']?.toString() ??
        '';
  }

  Widget _patientIdCard() {
    final patientId = _patientId();

    if (patientId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Your Patient ID',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Give this ID to your caregiver so they can send you a connection request.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: SelectableText(
                patientId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return {};
  }

  double _accuracy() {
    final directAccuracy =
        _summary['average_accuracy'];

    if (directAccuracy is num) {
      return directAccuracy
          .toDouble()
          .clamp(0, 100);
    }

    final byGameType =
        _summary['by_game_type'];

    if (byGameType is Map &&
        byGameType.isNotEmpty) {
      double total = 0;
      int count = 0;

      for (final value in byGameType.values) {
        if (value is Map) {
          final map =
              Map<String, dynamic>.from(
            value,
          );

          final accuracy =
              map['average_accuracy'] ??
              map['accuracy'];

          if (accuracy is num) {
            total += accuracy.toDouble();
            count++;
          }
        }
      }

      if (count > 0) {
        return (total / count).clamp(
          0,
          100,
        );
      }
    }

    return 0;
  }

  int _totalAttempts() {
    final value =
        _summary['total_attempts'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // Actual number of game sessions.
  int _totalSessions() {
    final value =
        _summary['total_sessions'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _trend() {
    final trend =
        _summary['trend']?.toString();

    if (trend == null || trend.isEmpty) {
      return 'insufficient_data';
    }

    return trend;
  }

  String _recommendationText() {
    final recommendation = _map(
      _nextSession['recommendation'],
    );

    if (recommendation.isNotEmpty) {
      final gameType =
          recommendation['game_type']
              ?.toString();

      final difficulty =
          recommendation['difficulty']
              ?.toString();

      final reason =
          recommendation['reason']
              ?.toString();

      if (reason != null &&
          reason.isNotEmpty) {
        return reason;
      }

      if (gameType != null &&
          difficulty != null) {
        return 'Today, try a $gameType game '
            'at difficulty $difficulty.';
      }

      if (gameType != null) {
        return 'Today, try a $gameType '
            'cognitive game.';
      }
    }

    final directReason =
        _nextSession['reason']?.toString();

    if (directReason != null &&
        directReason.isNotEmpty) {
      return directReason;
    }

    return 'Keep practicing regularly to '
        'maintain your cognitive engagement.';
  }

  String _recommendedGame() {
    final recommendation = _map(
      _nextSession['recommendation'],
    );

    final gameType =
        recommendation['game_type']
            ?.toString();

    if (gameType == null ||
        gameType.isEmpty) {
      return 'Cognitive Game';
    }

    switch (gameType.toLowerCase()) {
      case 'memory':
        return 'Memory Game';

      case 'attention':
        return 'Attention Game';

      case 'pattern':
        return 'Pattern Game';

      default:
        return gameType;
    }
  }

  int _recommendedDifficulty() {
    final recommendation = _map(
      _nextSession['recommendation'],
    );

    final difficulty =
        recommendation['difficulty'];

    if (difficulty is num) {
      return difficulty
          .toInt()
          .clamp(1, 5);
    }

    return 1;
  }

  // ============================================================
  // CAREGIVER REQUESTS
  // ============================================================

  Future<void> _acceptCaregiverRequest(
    Map<String, dynamic> request,
  ) async {
    final linkId =
        request['id']?.toString() ??
        request['_id']?.toString() ??
        request['link_id']?.toString();

    if (linkId == null || linkId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to identify this caregiver request.',
          ),
        ),
      );

      return;
    }

    if (_acceptingCaregiverRequests
        .contains(linkId)) {
      return;
    }

    setState(() {
      _acceptingCaregiverRequests.add(
        linkId,
      );
    });

    try {
      await ApiService.acceptCaregiverLink(
        token: widget.token,
        linkId: linkId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _caregiverRequests.removeWhere(
          (item) {
            if (item is! Map) {
              return false;
            }

            final map =
                Map<String, dynamic>.from(
              item,
            );

            final id =
                map['id']?.toString() ??
                map['_id']?.toString() ??
                map['link_id']?.toString();

            return id == linkId;
          },
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caregiver request accepted successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _acceptingCaregiverRequests.remove(
            linkId,
          );
        });
      }
    }
  }

  Widget _caregiverRequestsSection() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(
                    Icons.person_add_alt_1,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _caregiverRequests.length == 1
                        ? 'Caregiver Request'
                        : 'Caregiver Requests',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    '${_caregiverRequests.length}',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Someone wants permission to view '
              'your cognitive care information.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            ..._caregiverRequests.map(
              (item) {
                if (item is! Map) {
                  return const SizedBox.shrink();
                }

                final request =
                    Map<String, dynamic>.from(
                  item,
                );

                return _caregiverRequestTile(
                  request,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _caregiverRequestTile(
    Map<String, dynamic> request,
  ) {
    final linkId =
        request['id']?.toString() ??
        request['_id']?.toString() ??
        request['link_id']?.toString() ??
        '';

    final relationship =
        request['relationship']
            ?.toString() ??
        'Caregiver';

    final caregiverName =
        request['caregiver_name']
            ?.toString() ??
        request['name']?.toString() ??
        'Caregiver';

    final accepting =
        _acceptingCaregiverRequests
            .contains(linkId);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 23,
                child: Icon(
                  Icons.person,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      caregiverName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      relationship,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: accepting
                  ? null
                  : () {
                      _acceptCaregiverRequest(
                        request,
                      );
                    },
              icon: accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle,
                    ),
              label: Text(
                accepting
                    ? 'ACCEPTING...'
                    : 'ACCEPT CAREGIVER',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Future<void> _showProgress() async {
    final accuracy = _accuracy();

    final sessions = _totalSessions();

    final trend = _trend();

    String trendLabel;

    switch (trend) {
      case 'improving':
        trendLabel = 'Improving';
        break;

      case 'declining':
        trendLabel =
            'Needs a little more practice';
        break;

      case 'stable':
        trendLabel = 'Stable';
        break;

      default:
        trendLabel =
            'Building baseline';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'My Progress',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              _dialogMetric(
                Icons.percent,
                'Accuracy',
                '${accuracy.toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 12),
              _dialogMetric(
                Icons.games,
                'Game Sessions',
                '$sessions',
              ),
              const SizedBox(height: 12),
              _dialogMetric(
                Icons.trending_up,
                'Trend',
                trendLabel,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogMetric(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'caregiver') {
      return CognitiveDashboardScreen(
        token: widget.token,
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FC),

      appBar: AppBar(
        title: const Text(
          'SmiritiSarthi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _loading ? null : _load,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
            ),
            tooltip: 'Logout',
          ),
        ],
      ),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _welcome(),

          const SizedBox(height: 18),

          _patientIdCard(),

          const SizedBox(height: 18),

          if (_caregiverRequests.isNotEmpty) ...[
            _caregiverRequestsSection(),
            const SizedBox(height: 18),
          ],

          _recommendationCard(),

          const SizedBox(height: 18),

          _memoryMomentCard(),

          const SizedBox(height: 18),

          _journeyCard(),

          const SizedBox(height: 18),

          _familyCard(),

          const SizedBox(height: 24),

          _title('Cognitive Games'),

          const SizedBox(height: 12),

          _card(
            title: 'Memory Game',
            subtitle:
                'Train recall and memory',
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
            subtitle:
                'Improve focus and concentration',
            icon:
                Icons.center_focus_strong,
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
            subtitle:
                'Practice pattern recognition',
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
                        patientId:
                            _patientId(),
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
                        patientId:
                            _patientId(),
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
                  _showProgress,
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
                        patientId:
                            _patientId(),
                        language:
                            _patient['language']
                                ?.toString() ??
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
                'SmiritiSarthi supports cognitive '
                'engagement and personalized practice. '
                'It does not diagnose or treat dementia '
                'or any medical condition.',
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

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load your dashboard.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _error ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'TRY AGAIN',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _welcome() {
    final name =
        _patient['name']?.toString() ??
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
                    style:
                        const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
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

  // ============================================================
  // RECOMMENDATION
  // ============================================================

  Widget _recommendationCard() {
    final difficulty =
        _recommendedDifficulty();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(
                    Icons.auto_awesome,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Text(
                    'Today’s Recommendation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              _recommendationText(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.games,
                    size: 18,
                  ),
                  label: Text(
                    _recommendedGame(),
                  ),
                ),

                const SizedBox(width: 8),

                Chip(
                  avatar: const Icon(
                    Icons.speed,
                    size: 18,
                  ),
                  label: Text(
                    'Level $difficulty',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MEMORY MOMENT
  // ============================================================

  Widget _memoryMomentCard() {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _open(
            MemoryMomentScreen(
              token: widget.token,
              patientId: _patientId(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Colors.pink.shade50,
                child: Icon(
                  Icons.favorite,
                  size: 28,
                  color: Colors.pink.shade400,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memory Moment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Remember the people and moments in your life',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.pink.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // JOURNEY CARD
  // ============================================================

  Widget _journeyCard() {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _open(
            JourneyAssistScreen(
              token: widget.token,
              patientId: _patientId(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Colors.blue.shade50,
                child: Icon(
                  Icons.explore,
                  size: 28,
                  color: Colors.blue.shade400,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journey',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Get help when you need to go somewhere',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.blue.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FAMILY CARD
  // ============================================================

  Widget _familyCard() {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _open(
            FamilyRecognitionScreen(
              token: widget.token,
              patientId: _patientId(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Colors.teal.shade50,
                child: Icon(
                  Icons.people,
                  size: 28,
                  color: Colors.teal.shade400,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Family',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'See photos and learn about your family',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.teal.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // LARGE CARD
  // ============================================================

  Widget _card({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
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
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SMALL CARD
  // ============================================================

  Widget _small(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
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
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _progress() {
    final accuracy = _accuracy();

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
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Overall Accuracy',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  '${accuracy.toStringAsFixed(0)}%',
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),
              child:
                  LinearProgressIndicator(
                value: accuracy / 100,
                minHeight: 12,
              ),
            ),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                _progressStat(
                  'Sessions',
                  '${_totalSessions()}',
                ),

                _progressStat(
                  'Attempts',
                  '${_totalAttempts()}',
                ),

                _progressStat(
                  'Trend',
                  _trend(),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Your progress is based on your '
              'cognitive game sessions.',
              style: TextStyle(
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressStat(
    String title,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Widget _notificationSummary() {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.notifications,
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'You have recent updates and reminders.',
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
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