import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/offline_queue.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.patientId,
    required this.token,
    required this.gameType,
    this.difficulty = 1,
  });

  final String patientId;
  final String token;
  final String gameType;
  final int difficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Map<String, dynamic>? challenge;
  String? sessionId;
  String? error;

  bool loading = true;
  bool submitting = false;
  bool memorising = true;

  final selected = <String>{};
  String? patternAnswer;

  final attentionController = TextEditingController();
  final stopwatch = Stopwatch();

  Timer? timer;

  String get title =>
      '${widget.gameType[0].toUpperCase()}'
      '${widget.gameType.substring(1)} Game';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final result = await ApiService.startGame(
        token: widget.token,
        patientId: widget.patientId,
        gameType: widget.gameType,
        difficulty: widget.difficulty,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        challenge =
            Map<String, dynamic>.from(result['challenge'] as Map);
        sessionId = result['game_session_id'] as String;
        loading = false;
        error = null;
        submitting = false;
        selected.clear();
        patternAnswer = null;
        attentionController.clear();
        memorising = true;
      });

      if (widget.gameType == 'memory') {
        timer?.cancel();

        timer = Timer(
          const Duration(seconds: 5),
          () {
            if (!mounted) {
              return;
            }

            setState(() {
              memorising = false;
              stopwatch.start();
            });
          },
        );
      } else {
        stopwatch.start();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  dynamic get _answer => switch (widget.gameType) {
        'memory' => selected.toList(),
        'pattern' => patternAnswer,
        _ => int.tryParse(attentionController.text.trim()),
      };

  bool get _canSubmit =>
      _answer != null &&
      !(widget.gameType == 'memory' && selected.isEmpty);

  int get _offlineScore {
    if (widget.gameType == 'memory') {
      final correct = Set<String>.from(
        (challenge?['objects'] as List)
            .map((item) => item.toString()),
      );

      return selected.where(correct.contains).length;
    }

    if (widget.gameType == 'attention') {
      final grid = (challenge?['grid'] as List)
          .map((item) => item.toString());

      final correctCount =
          grid.where((item) => item == challenge?['target']).length;

      final answer = int.tryParse(
        attentionController.text.trim(),
      );

      return answer == correctCount ? 1 : 0;
    }

    // Pattern answers are verified on the server after reconnection.
    return 0;
  }

  Future<void> _submit() async {
    if (!_canSubmit || sessionId == null || submitting) {
      return;
    }

    stopwatch.stop();

    setState(() {
      submitting = true;
    });

    final elapsed = stopwatch.elapsedMilliseconds / 1000;

    try {
      final result = await ApiService.submitGame(
        token: widget.token,
        patientId: widget.patientId,
        gameType: widget.gameType,
        sessionId: sessionId!,
        reactionTime: elapsed,
        hintsUsed: 0,
        answer: _answer,
      );

      if (!mounted) {
        return;
      }

      await _result(result, false);
    } catch (_) {
      // A locally completed activity is kept for secure,
      // idempotent synchronization.
      final maxScore = widget.gameType == 'memory'
          ? (challenge?['objects'] as List).length
          : 1;

      final offlineScore = _offlineScore;

      await OfflineQueue.enqueueAttempt({
        'game_type': widget.gameType,
        'patient_id': widget.patientId,
        'score': offlineScore,
        'max_score': maxScore,
        'accuracy': offlineScore * 100 / maxScore,
        'reaction_time': elapsed,
        'hints_used': 0,
        'difficulty': widget.difficulty,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        await _result(
          {
            'performance_score': 0,
            'next_difficulty': widget.difficulty,
          },
          true,
        );
      }
    }
  }

  Future<void> _result(
    Map<String, dynamic> result,
    bool queued,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Well done!'),
        content: Text(
          queued
              ? 'Your activity was saved on this device and will sync '
                  'when you reconnect.'
              : 'Activity score: ${result['performance_score']}\n'
                  'Next difficulty: ${result['next_difficulty']}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    stopwatch.stop();
    attentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : error != null
                ? _error()
                : _game(),
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _start,
              child: const Text('TRY AGAIN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _game() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _challenge(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: ElevatedButton(
              onPressed:
                  submitting || !_canSubmit ? null : _submit,
              child: submitting
                  ? const CircularProgressIndicator()
                  : const Text(
                      'SUBMIT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _challenge() {
    if (widget.gameType == 'memory') {
      return Column(
        children: [
          Text(
            memorising
                ? 'Remember these objects'
                : 'Select all the objects you remember',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: (challenge![
                memorising ? 'objects' : 'options'
              ] as List)
                  .map<Widget>(
                (item) {
                  final value = item.toString();
                  final active = selected.contains(value);

                  return Semantics(
                    button: !memorising,
                    label: value,
                    child: InkWell(
                      onTap: memorising
                          ? null
                          : () {
                              setState(() {
                                if (active) {
                                  selected.remove(value);
                                } else {
                                  selected.add(value);
                                }
                              });
                            },
                      child: Card(
                        color: active
                            ? Colors.blue.shade100
                            : null,
                        child: Center(
                          child: Text(
                            value.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      );
    }

    if (widget.gameType == 'pattern') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'What comes next?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${(challenge!['pattern'] as List).join('   ')}   ?',
            style: const TextStyle(fontSize: 34),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            children: [
              'A',
              'B',
              'C',
              'D',
              '1',
              '2',
              '3',
              '4',
              'W',
              'X',
              'Y',
              'Z',
            ].map(
              (value) {
                return ChoiceChip(
                  label: Text(
                    value,
                    style: const TextStyle(fontSize: 20),
                  ),
                  selected: patternAnswer == value,
                  onSelected: (_) {
                    setState(() {
                      patternAnswer = value;
                    });
                  },
                );
              },
            ).toList(),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'How many ${challenge!['target']}s can you see?',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (challenge!['grid'] as List)
              .map(
                (item) => Chip(
                  label: Text(
                    item.toString(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: attentionController,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            setState(() {});
          },
          decoration: const InputDecoration(
            labelText: 'Your answer',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}