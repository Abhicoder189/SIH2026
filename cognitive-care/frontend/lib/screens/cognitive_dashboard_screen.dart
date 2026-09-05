
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'caregiver_memory_manager_screen.dart';
import 'caregiver_journey_screen.dart';
import 'login_screen.dart';

class CognitiveDashboardScreen extends StatefulWidget {
  final String token;

  const CognitiveDashboardScreen({
    super.key,
    required this.token,
  });

  @override
  State<CognitiveDashboardScreen> createState() =>
      _CognitiveDashboardScreenState();
}

class _CognitiveDashboardScreenState
    extends State<CognitiveDashboardScreen> {
  List<dynamic> patients = [];
  List<dynamic> pendingRequests = [];

  bool loading = true;
  bool linking = false;
  bool loggingOut = false;

  String? error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      List<dynamic> activePatients = [];
      List<dynamic> myRequests = [];

      try {
        activePatients = await ApiService.caregiverPatients(
          widget.token,
        );
      } catch (_) {}

      try {
        myRequests = await ApiService.caregiverMyRequests(
          widget.token,
        );
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        patients = activePatients;
        pendingRequests = myRequests;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
        loading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadPatientData(
    String patientId,
  ) async {
    Map<String, dynamic> analytics = {};

    try {
      final patientsResult = await ApiService.caregiverPatients(
        widget.token,
      );

      for (final p in patientsResult) {
        final map = Map<String, dynamic>.from(p);
        if (map['patient_id']?.toString() == patientId) {
          analytics = _map(map['analytics']);
          break;
        }
      }
    } catch (_) {}

    dynamic activity;
    try {
      activity = await ApiService.getDailyActivity(
        widget.token,
        patientId,
      );
    } catch (_) {}

    dynamic recommendation;
    try {
      recommendation = await ApiService.getDifficultyRecommendation(
        widget.token,
        patientId,
      );
    } catch (_) {}

    final byGameType = _map(analytics['by_game_type']);

    Map<String, dynamic> normalizeGame(Map<String, dynamic> raw) {
      return {
        'accuracy': raw['average_accuracy'] ?? 0,
        'difficulty': raw['current_difficulty'] ?? 1,
      };
    }

    return {
      'profile': {
        'total_sessions': analytics['total_sessions'] ?? 0,
        'overall_score': analytics['average_accuracy'] ?? 0,
        'memory': normalizeGame(_map(byGameType['memory'])),
        'attention': normalizeGame(_map(byGameType['attention'])),
        'pattern': normalizeGame(_map(byGameType['pattern'])),
      },
      'activity': activity ?? {},
      'alerts': {'alerts': []},
      'recommendation': recommendation ?? {},
    };
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _integer(
    dynamic value, [
    int fallback = 0,
  ]) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<dynamic> _list(dynamic value) {
    if (value is List) {
      return value;
    }

    return [];
  }

  Future<void> _showLinkPatientDialog() async {
    final patientIdController = TextEditingController();

    String relationship = 'Caregiver';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Link Patient',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter the Patient ID provided by the elderly user.',
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: patientIdController,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Patient ID',
                        hintText: 'Example: 65f123...',
                        prefixIcon: Icon(
                          Icons.person_search,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: relationship,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        prefixIcon: Icon(
                          Icons.people,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Caregiver',
                          child: Text('Caregiver'),
                        ),
                        DropdownMenuItem(
                          value: 'Son',
                          child: Text('Son'),
                        ),
                        DropdownMenuItem(
                          value: 'Daughter',
                          child: Text('Daughter'),
                        ),
                        DropdownMenuItem(
                          value: 'Spouse',
                          child: Text('Spouse'),
                        ),
                        DropdownMenuItem(
                          value: 'Family Member',
                          child: Text('Family Member'),
                        ),
                        DropdownMenuItem(
                          value: 'Health Worker',
                          child: Text('Health Worker'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          relationship = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: linking
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            false,
                          );
                        },
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontSize: 17,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: linking
                      ? null
                      : () {
                          final patientId =
                              patientIdController.text.trim();

                          if (patientId.isEmpty) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter the Patient ID.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        },
                  icon: linking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.link,
                        ),
                  label: Text(
                    linking
                        ? 'SENDING...'
                        : 'SEND REQUEST',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      patientIdController.dispose();
      return;
    }

    final patientId =
        patientIdController.text.trim();

    patientIdController.dispose();

    await _sendLinkRequest(
      patientId: patientId,
      relationship: relationship,
    );
  }

  Future<void> _sendLinkRequest({
    required String patientId,
    required String relationship,
  }) async {
    if (mounted) {
      setState(() {
        linking = true;
      });
    }

    try {
      // IMPORTANT:
      // ApiService uses requestCaregiverLink(),
      // not createCaregiverLink().
      final result =
          await ApiService.requestCaregiverLink(
        token: widget.token,
        patientId: patientId,
        relationship: relationship,
      );

      if (!mounted) {
        return;
      }

      final status =
          result['status']?.toString() ?? 'pending';

      if (status == 'active') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Patient is already linked.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection request sent. Ask the patient to accept it.',
            ),
          ),
        );
      }

      await _loadPatients();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          linking = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (loggingOut) {
      return;
    }

    setState(() {
      loggingOut = true;
    });

    try {
      await ApiService.logout(
        widget.token,
      );
    } catch (_) {
      // Clear local session even if server logout fails.
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
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SmiritiSarthi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading
                ? null
                : _loadPatients,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: loggingOut
                ? null
                : _logout,
            icon: loggingOut
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.logout,
                  ),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: linking
            ? null
            : _showLinkPatientDialog,
        icon: linking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.person_add,
              ),
        label: Text(
          linking
              ? 'SENDING...'
              : 'LINK PATIENT',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load patients.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadPatients,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (patients.isEmpty && pendingRequests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100,
        ),
        itemCount: patients.length + pendingRequests.length,
        itemBuilder: (
          context,
          index,
        ) {
          if (index < pendingRequests.length) {
            return _pendingRequestCard(
              pendingRequests[index],
            );
          }

          final patient =
              Map<String, dynamic>.from(
            patients[index - pendingRequests.length],
          );

          final patientObject =
              _map(patient['patient']);

          final patientId =
              (
                patient['patient_id'] ??
                patientObject['patient_id'] ??
                patientObject['id'] ??
                patient['id']
              ).toString();

          final patientName =
              (
                patient['name'] ??
                patientObject['name']
              )?.toString() ??
              'Patient';

          final language =
              (
                patient['language'] ??
                patientObject['language']
              )?.toString() ??
              'Language not set';

          final relationship =
              patient['relationship']?.toString() ??
              'Caregiver';

          return Card(
            margin: const EdgeInsets.only(
              bottom: 16,
            ),
            child: ExpansionTile(
              leading: const CircleAvatar(
                radius: 26,
                child: Icon(
                  Icons.person,
                ),
              ),
              title: Text(
                patientName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '$relationship • $language',
              ),
              children: [
                FutureBuilder<
                    Map<String, dynamic>?>(
                  future: _loadPatientData(
                    patientId,
                  ),
                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Unable to load patient information.',
                          textAlign:
                              TextAlign.center,
                        ),
                      );
                    }

                    final data =
                        snapshot.data!;

                    final profile =
                        _map(data['profile']);

                    final activity =
                        _map(data['activity']);

                    final alertsData =
                        _map(data['alerts']);

                    final recommendation =
                        _map(
                      data['recommendation'],
                    );

                    return _buildPatientDetails(
                      patientId: patientId,
                      patientName: patientName,
                      profile: profile,
                      activity: activity,
                      alertsData: alertsData,
                      recommendation:
                          recommendation,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'No linked patients yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Link an elderly user using their Patient ID. '
              'The patient will need to accept your request '
              'before their information appears here.\n\n'
              'After sending a request, you will see it '
              'marked as "Waiting for acceptance" until '
              'the patient approves it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: linking
                  ? null
                  : _showLinkPatientDialog,
              icon: const Icon(
                Icons.person_add,
              ),
              label: const Text(
                'LINK A PATIENT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingRequestCard(
    Map<String, dynamic> request,
  ) {
    final patientName =
        request['patient_name']?.toString() ??
        'Patient';

    final relationship =
        request['relationship']?.toString() ??
        'Caregiver';

    final createdAt = request['created_at'];

    String timeAgo = '';
    if (createdAt != null) {
      timeAgo = 'Sent recently';
    }

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.orange.shade100,
              child: Icon(
                Icons.hourglass_top,
                color: Colors.orange.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$relationship • Waiting for acceptance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  if (timeAgo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.pending,
              color: Colors.orange.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDetails({
    required String patientId,
    required String patientName,
    required Map<String, dynamic> profile,
    required Map<String, dynamic> activity,
    required Map<String, dynamic> alertsData,
    required Map<String, dynamic> recommendation,
  }) {
    final totalSessions = _integer(
      profile['total_sessions'],
    );

    final overallScore = _number(
      profile['overall_score'],
    );

    final gamesCompleted = _integer(
      activity['games_completed'],
    );

    final alerts = _list(
      alertsData['alerts'],
    );

    final recommendedDifficulty =
        _integer(
      recommendation['difficulty'],
      1,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 14),
          _buildActivityCard(
            gamesCompleted: gamesCompleted,
            totalSessions: totalSessions,
            overallScore: overallScore,
          ),
          const SizedBox(height: 14),
          _buildPerformanceSection(
            profile,
          ),
          const SizedBox(height: 14),
          _buildRecommendationCard(
            recommendation,
            recommendedDifficulty,
          ),
          const SizedBox(height: 14),
          _buildAlertsSection(
            alerts,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CaregiverMemoryManagerScreen(
                      token: widget.token,
                      patientId: patientId,
                      patientName: patientName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.favorite, size: 22),
              label: const Text(
                'MANAGE MEMORIES',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade50,
                foregroundColor: Colors.pink.shade700,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CaregiverJourneyScreen(
                      token: widget.token,
                      patientId: patientId,
                      patientName: patientName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.explore, size: 22),
              label: const Text(
                'JOURNEY',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard({
    required int gamesCompleted,
    required int totalSessions,
    required double overallScore,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity Overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statItem(
                    Icons.games,
                    'Today',
                    '$gamesCompleted games',
                  ),
                ),
                Expanded(
                  child: _statItem(
                    Icons.history,
                    'Sessions',
                    '$totalSessions',
                  ),
                ),
                Expanded(
                  child: _statItem(
                    Icons.insights,
                    'Overall',
                    '${overallScore.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 28,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(
    Map<String, dynamic> profile,
  ) {
    final memory = _map(
      profile['memory'],
    );

    final attention = _map(
      profile['attention'],
    );

    final pattern = _map(
      profile['pattern'],
    );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Cognitive Performance',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _performanceRow(
              'Memory',
              Icons.psychology,
              memory,
            ),
            const SizedBox(height: 14),
            _performanceRow(
              'Attention',
              Icons.visibility,
              attention,
            ),
            const SizedBox(height: 14),
            _performanceRow(
              'Pattern',
              Icons.grid_view,
              pattern,
            ),
          ],
        ),
      ),
    );
  }

  Widget _performanceRow(
    String title,
    IconData icon,
    Map<String, dynamic> data,
  ) {
    final accuracy = _number(
      data['accuracy'],
    );

    final difficulty = _integer(
      data['difficulty'],
      1,
    );

    final progress =
        (accuracy / 100).clamp(
      0.0,
      1.0,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Level $difficulty',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Accuracy: '
          '${accuracy.toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> recommendation,
    int difficulty,
  ) {
    final method =
        recommendation['method']
                ?.toString() ??
            'rule_based';

    final confidence =
        recommendation['confidence'];

    final confidenceText =
        confidence == null
            ? 'Not enough history for ML yet.'
            : 'AI confidence: $confidence%';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                ),
                SizedBox(width: 10),
                Text(
                  'AI Personalization',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Recommended next difficulty: '
              'Level $difficulty',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              method == 'ml_random_forest'
                  ? 'Recommendation based on historical game performance.'
                  : 'Using the safe rule-based fallback.',
            ),
            const SizedBox(height: 6),
            Text(
              confidenceText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(
    List<dynamic> alerts,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications,
                ),
                const SizedBox(width: 10),
                Text(
                  'Engagement Alerts (${alerts.length})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              const Text(
                'No current engagement alerts.',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ...alerts.map(
              (alert) {
                final item = _map(alert);

                final severity =
                    item['severity']
                        ?.toString()
                        .toLowerCase();

                final icon =
                    severity == 'high'
                        ? Icons.warning
                        : Icons.info_outline;

                return ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Icon(icon),
                  title: Text(
                    item['title']
                            ?.toString() ??
                        'Attention',
                  ),
                  subtitle: Text(
                    item['message']
                            ?.toString() ??
                        '',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

