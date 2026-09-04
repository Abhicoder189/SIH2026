import 'package:flutter/material.dart';

import '../services/api_service.dart';

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
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result =
          await ApiService.caregiverPatients(widget.token);

      if (!mounted) return;

      setState(() {
        patients = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadPatientData(
    String patientId,
  ) async {
    try {
      final results = await Future.wait([
        ApiService.getCognitiveProfile(
          widget.token,
          patientId,
        ),
        ApiService.getDailyActivity(
          widget.token,
          patientId,
        ),
        ApiService.getAlerts(
          widget.token,
          patientId,
          caregiver: true,
        ),
        ApiService.getDifficultyRecommendation(
          widget.token,
          patientId,
        ),
      ]);

      return {
        'profile': results[0],
        'activity': results[1],
        'alerts': results[2],
        'recommendation': results[3],
      };
    } catch (_) {
      return null;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caregiver Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _loadPatients,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
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
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (patients.isEmpty) {
      return const Center(
        child: Text(
          'No linked patients yet.',
          style: TextStyle(fontSize: 20),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: patients.length,
        itemBuilder: (context, index) {
          final patient =
              Map<String, dynamic>.from(patients[index]);

          final patientId =
              (patient['patient_id'] ?? patient['id']).toString();

          final patientName =
              patient['name']?.toString() ?? 'Patient';

          final language =
              patient['language']?.toString() ??
                  'Language not set';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: const CircleAvatar(
                radius: 26,
                child: Icon(Icons.person),
              ),
              title: Text(
                patientName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(language),
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: _loadPatientData(patientId),
                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Unable to load patient information.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final data = snapshot.data!;

                    final profile =
                        _map(data['profile']);

                    final activity =
                        _map(data['activity']);

                    final alertsData =
                        _map(data['alerts']);

                    final recommendation =
                        _map(data['recommendation']);

                    return _buildPatientDetails(
                      profile: profile,
                      activity: activity,
                      alertsData: alertsData,
                      recommendation: recommendation,
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

  Widget _buildPatientDetails({
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

    final recommendedDifficulty = _integer(
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

          _buildPerformanceSection(profile),

          const SizedBox(height: 14),

          _buildRecommendationCard(
            recommendation,
            recommendedDifficulty,
          ),

          const SizedBox(height: 14),

          _buildAlertsSection(alerts),
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
    final memory =
        _map(profile['memory']);

    final attention =
        _map(profile['attention']);

    final pattern =
        _map(profile['pattern']);

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
        (accuracy / 100).clamp(0.0, 1.0);

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
        recommendation['method']?.toString() ??
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
                Icon(Icons.auto_awesome),
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

            Text(confidenceText),
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
                const Icon(Icons.notifications),
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
                style: TextStyle(fontSize: 16),
              ),

            ...alerts.map(
              (alert) {
                final item =
                    _map(alert);

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
                    item['title']?.toString() ??
                        'Attention',
                  ),
                  subtitle: Text(
                    item['message']?.toString() ??
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