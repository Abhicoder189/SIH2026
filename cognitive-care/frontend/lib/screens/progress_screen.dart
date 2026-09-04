import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  final String patientId;
  final String token;

  const ProgressScreen({
    super.key,
    required this.patientId,
    required this.token,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _analytics;
  List<dynamic> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // IMPORTANT:
      // ApiService expects TOKEN first and PATIENT ID second.
      final performance =
          await ApiService.getPatientPerformance(
        widget.token,
        widget.patientId,
      );

      final attempts =
          await ApiService.getGameAttempts(
        widget.token,
        widget.patientId,
      );

      if (!mounted) return;

      setState(() {
        _analytics = Map<String, dynamic>.from(
          performance['analytics'] ?? {},
        );

        _attempts = attempts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  double _number(
    dynamic value, [
    double fallback = 0,
  ]) {
    if (value is num) {
      return value.toDouble();
    }

    return fallback;
  }

  String _percentage(dynamic value) {
    return '${_number(value).toStringAsFixed(0)}%';
  }

  double _gameAverage(String gameType) {
    final scores = _attempts
        .where(
          (attempt) =>
              attempt is Map &&
              attempt['game_type'] == gameType,
        )
        .map(
          (attempt) => _number(
            attempt['performance_score'],
          ),
        )
        .toList();

    if (scores.isEmpty) {
      return 0;
    }

    return scores.reduce((a, b) => a + b) /
        scores.length;
  }

  int _activeDays() {
    final dates = <String>{};

    for (final attempt in _attempts) {
      if (attempt is! Map) continue;

      final date = attempt['created_at'];

      if (date != null) {
        final dateString = date.toString();

        dates.add(
          dateString.substring(
            0,
            dateString.length >= 10
                ? 10
                : dateString.length,
          ),
        );
      }
    }

    return dates.length;
  }

  int _thisWeekCount() {
    final now = DateTime.now();

    final startOfWeek = now.subtract(
      Duration(
        days: now.weekday - 1,
      ),
    );

    int count = 0;

    for (final attempt in _attempts) {
      if (attempt is! Map) continue;

      final rawDate = attempt['created_at'];

      if (rawDate == null) continue;

      final date = DateTime.tryParse(
        rawDate.toString(),
      );

      if (date == null) continue;

      final beginningOfWeek = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );

      if (date.isAfter(beginningOfWeek) ||
          date.isAtSameMomentAs(beginningOfWeek)) {
        count++;
      }
    }

    return count;
  }

  String _trendText() {
    final trend =
        _analytics?['trend']
            ?.toString()
            .toLowerCase();

    switch (trend) {
      case 'improving':
      case 'up':
      case 'positive':
        return 'Improving ↑';

      case 'declining':
      case 'down':
      case 'negative':
        return 'Needs attention ↓';

      default:
        return 'Stable →';
    }
  }

  IconData _trendIcon() {
    final trend =
        _analytics?['trend']
            ?.toString()
            .toLowerCase();

    if (trend == 'improving' ||
        trend == 'up' ||
        trend == 'positive') {
      return Icons.trending_up;
    }

    if (trend == 'declining' ||
        trend == 'down' ||
        trend == 'negative') {
      return Icons.trending_down;
    }

    return Icons.trending_flat;
  }

  Color _trendColor() {
    final trend =
        _analytics?['trend']
            ?.toString()
            .toLowerCase();

    if (trend == 'improving' ||
        trend == 'up' ||
        trend == 'positive') {
      return Colors.green;
    }

    if (trend == 'declining' ||
        trend == 'down' ||
        trend == 'negative') {
      return Colors.orange;
    }

    return Colors.blue;
  }

  String _gameName(String type) {
    switch (type) {
      case 'memory':
        return 'Memory';

      case 'pattern':
        return 'Pattern';

      case 'attention':
        return 'Attention';

      default:
        return type;
    }
  }

  IconData _gameIcon(String type) {
    switch (type) {
      case 'memory':
        return Icons.psychology;

      case 'pattern':
        return Icons.grid_4x4;

      case 'attention':
        return Icons.visibility;

      default:
        return Icons.games;
    }
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 30,
              ),

              const SizedBox(height: 10),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                title,
                textAlign: TextAlign.center,
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

  Widget _gameCard({
    required String name,
    required double score,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              child: Icon(icon),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 9),

                  LinearProgressIndicator(
                    value: (score / 100).clamp(0, 1),
                    minHeight: 9,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 15),

            Text(
              '${score.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentActivity() {
    final recent = List<dynamic>.from(_attempts)
      ..sort((a, b) {
        final aDate =
            DateTime.tryParse(
                  a['created_at']?.toString() ?? '',
                ) ??
                DateTime(2000);

        final bDate =
            DateTime.tryParse(
                  b['created_at']?.toString() ?? '',
                ) ??
                DateTime(2000);

        return bDate.compareTo(aDate);
      });

    final items = recent.take(5).toList();

    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No completed activities yet.\n'
            'Play a game to start building your progress.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          ...items.map(
            (attempt) {
              final type =
                  attempt['game_type']
                      ?.toString() ??
                  'game';

              final score = _number(
                attempt['performance_score'],
              );

              return ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    _gameIcon(type),
                  ),
                ),

                title: Text(
                  _gameName(type),
                ),

                subtitle: Text(
                  'Difficulty '
                  '${attempt['difficulty'] ?? 1}',
                ),

                trailing: Text(
                  '${score.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final overall = _number(
      _analytics?['average_performance_score'],
    );

    final accuracy = _number(
      _analytics?['average_accuracy'],
    );

    final reactionTime = _number(
      _analytics?['average_reaction_time'],
    );

    final difficulty =
        (_analytics?['current_difficulty'] ?? 1)
            .toString();

    return RefreshIndicator(
      onRefresh: _loadProgress,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'My Progress',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Your cognitive activity overview',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 25),

          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Text(
                    'Overall Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '${overall.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        _trendIcon(),
                        color: _trendColor(),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        _trendText(),
                        style: TextStyle(
                          color: _trendColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              _metricCard(
                title: 'Activities',
                value: '${_attempts.length}',
                icon: Icons.sports_esports,
              ),

              const SizedBox(width: 10),

              _metricCard(
                title: 'Active Days',
                value: '${_activeDays()}',
                icon: Icons.calendar_month,
              ),

              const SizedBox(width: 10),

              _metricCard(
                title: 'This Week',
                value: '${_thisWeekCount()}',
                icon: Icons.date_range,
              ),
            ],
          ),

          const SizedBox(height: 25),

          const Text(
            'Cognitive Areas',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _gameCard(
            name: 'Memory',
            score: _gameAverage('memory'),
            icon: Icons.psychology,
          ),

          _gameCard(
            name: 'Attention',
            score: _gameAverage('attention'),
            icon: Icons.visibility,
          ),

          _gameCard(
            name: 'Pattern Recognition',
            score: _gameAverage('pattern'),
            icon: Icons.grid_4x4,
          ),

          const SizedBox(height: 25),

          const Text(
            'Performance Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _detailRow(
                    'Average Accuracy',
                    _percentage(accuracy),
                  ),

                  const Divider(),

                  _detailRow(
                    'Average Reaction Time',
                    '${reactionTime.toStringAsFixed(1)} s',
                  ),

                  const Divider(),

                  _detailRow(
                    'Current Difficulty',
                    difficulty,
                  ),

                  const Divider(),

                  _detailRow(
                    'Completed Sessions',
                    '${_analytics?['completed_sessions'] ?? 0}',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          _recentActivity(),

          const SizedBox(height: 25),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 35,
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Text(
                      overall >= 80
                          ? 'Wonderful work! Keep your '
                            'daily practice going.'
                          : overall >= 50
                              ? 'Good progress! Regular '
                                'practice can help you stay engaged.'
                              : 'Every attempt counts. '
                                'Keep practicing at your own pace.',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _detailRow(
    String title,
    String value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
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

  Widget _errorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 70,
              color: Colors.red,
            ),

            const SizedBox(height: 20),

            const Text(
              'Unable to load progress',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _loadProgress,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'My Progress',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _errorScreen()
              : _buildContent(),
    );
  }
}