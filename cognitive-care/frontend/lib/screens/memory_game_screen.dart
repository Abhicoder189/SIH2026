import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({
    super.key,
    required this.patientId,
    required this.token,
  });

  final String patientId;
  final String token;

  @override
  State<MemoryGameScreen> createState() =>
      _MemoryGameScreenState();
}

class _MemoryGameScreenState
    extends State<MemoryGameScreen> {
  bool _loading = true;
  bool _submitting = false;
  bool _gameFinished = false;

  String? _errorMessage;

  int _difficulty = 1;

  String? _gameSessionId;

  List<String> _objectsToRemember = [];
  List<String> _options = [];

  final Set<String> _selectedObjects = {};

  Timer? _memoryTimer;
  int _secondsRemaining = 5;

  DateTime? _challengeStartedAt;

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _memoryTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // START GAME
  // ============================================================

  Future<void> _startNewGame() async {
    _memoryTimer?.cancel();

    setState(() {
      _loading = true;
      _submitting = false;
      _gameFinished = false;
      _errorMessage = null;
      _gameSessionId = null;
      _objectsToRemember = [];
      _options = [];
      _selectedObjects.clear();
      _secondsRemaining = 5;
      _result = null;
      _challengeStartedAt = null;
    });

    try {
      final response = await ApiService.startMemoryGame(
        token: widget.token,
        patientId: widget.patientId,
        difficulty: _difficulty,
      );

      final challenge = Map<String, dynamic>.from(
        response['challenge'] ?? response,
      );

      final objects = List<String>.from(
        challenge['objects'] ?? [],
      );

      final options = List<String>.from(
        challenge['options'] ?? objects,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _gameSessionId =
            response['game_session_id']?.toString();

        _difficulty = int.tryParse(
              response['difficulty']?.toString() ?? '',
            ) ??
            _difficulty;

        _objectsToRemember = objects;
        _options = options;
        _loading = false;
        _secondsRemaining = 5;
      });

      _startMemoryCountdown();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // MEMORY COUNTDOWN
  // ============================================================

  void _startMemoryCountdown() {
    _memoryTimer?.cancel();

    _memoryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
            _challengeStartedAt = DateTime.now();
          });

          return;
        }

        setState(() {
          _secondsRemaining--;
        });
      },
    );
  }

  // ============================================================
  // SELECT OBJECT
  // ============================================================

  void _toggleObject(String object) {
    if (_loading ||
        _submitting ||
        _gameFinished ||
        _secondsRemaining > 0) {
      return;
    }

    setState(() {
      if (_selectedObjects.contains(object)) {
        _selectedObjects.remove(object);
      } else {
        _selectedObjects.add(object);
      }
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submitAnswer() async {
    if (_submitting ||
        _gameFinished ||
        _gameSessionId == null) {
      return;
    }

    if (_selectedObjects.isEmpty) {
      _showMessage(
        'Please select the objects you remember.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    final reactionTime = _challengeStartedAt == null
        ? 0.0
        : DateTime.now()
                .difference(_challengeStartedAt!)
                .inMilliseconds /
            1000.0;

    try {
      final response = await ApiService.submitMemoryGame(
        token: widget.token,
        patientId: widget.patientId,
        gameSessionId: _gameSessionId!,
        selectedObjects: _selectedObjects.toList(),
        reactionTime: reactionTime,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = response;
        _gameFinished = true;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // SCORE
  // ============================================================

  int get _localCorrectCount {
    return _selectedObjects
        .where(
          (object) => _objectsToRemember.contains(object),
        )
        .length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Memory Game',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    if (_gameFinished) {
      return _buildResult();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        if (_secondsRemaining > 0)
          _buildMemoryPhase()
        else
          _buildRecallPhase(),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Remember the objects',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Difficulty $_difficulty',
          style: TextStyle(
            fontSize: 18,
            color: Colors.indigo.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MEMORY PHASE
  // ============================================================

  Widget _buildMemoryPhase() {
    return Column(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.psychology,
                  size: 60,
                ),

                const SizedBox(height: 12),

                const Text(
                  'Remember these objects',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Look carefully. They will disappear soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 24),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: _objectsToRemember
                      .map(
                        (object) => _objectCard(
                          object,
                          large: true,
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 25),

                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.indigo.shade50,
                  ),
                  child: Center(
                    child: Text(
                      '$_secondsRemaining',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECALL PHASE
  // ============================================================

  Widget _buildRecallPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(
                  Icons.visibility_off,
                  size: 50,
                ),

                SizedBox(height: 10),

                Text(
                  'Which objects do you remember?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Tap all the objects you saw.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _options.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final object = _options[index];

            final selected =
                _selectedObjects.contains(object);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleObject(object),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.indigo.shade100
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? Colors.indigo
                        : Colors.grey.shade300,
                    width: selected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.05,
                      ),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    _objectIcon(
                      object,
                      size: 48,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      object,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (selected)
                      const Padding(
                        padding: EdgeInsets.only(
                          top: 5,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 22,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        Text(
          '${_selectedObjects.length} selected',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _submitting
                ? null
                : _submitAnswer,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                    ),
                  )
                : const Text(
                    'Submit Answer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OBJECT CARD
  // ============================================================

  Widget _objectCard(
    String object, {
    bool large = false,
  }) {
    return Container(
      width: large ? 105 : 90,
      height: large ? 105 : 90,
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _objectIcon(
            object,
            size: large ? 48 : 40,
          ),

          const SizedBox(height: 5),

          Text(
            object,
            style: TextStyle(
              fontSize: large ? 15 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OBJECT ICON
  // ============================================================

  Widget _objectIcon(
    String object, {
    double size = 48,
  }) {
    const icons = {
      'apple': '🍎',
      'milk': '🥛',
      'lamp': '💡',
      'flower': '🌸',
      'book': '📖',
      'cup': '☕',
      'rice': '🍚',
      'umbrella': '☂️',
      'clock': '🕐',
      'ball': '⚽',
      'tree': '🌳',
      'house': '🏠',
      'spoon': '🥄',
      'plate': '🍽️',
      'bottle': '🍼',
    };

    return Text(
      icons[object] ?? '🔹',
      style: TextStyle(
        fontSize: size,
      ),
    );
  }

  // ============================================================
  // RESULT
  // ============================================================

  Widget _buildResult() {
    final correct = int.tryParse(
          _result?['correct_count']?.toString() ?? '',
        ) ??
        _localCorrectCount;

    final total = int.tryParse(
          _result?['total_objects']?.toString() ?? '',
        ) ??
        _objectsToRemember.length;

    final performance = double.tryParse(
          _result?['performance_score']?.toString() ?? '',
        ) ??
        ((total == 0)
            ? 0
            : correct / total * 100);

    final nextDifficulty = int.tryParse(
      _result?['next_difficulty']?.toString() ?? '',
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),

        const Icon(
          Icons.celebration,
          size: 80,
        ),

        const SizedBox(height: 18),

        const Text(
          'Great Job!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Your game has been saved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 28),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                const Text(
                  'Your Score',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  '$correct / $total',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  '${performance.toStringAsFixed(0)}% performance',
                  style: TextStyle(
                    fontSize: 19,
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (nextDifficulty != null) ...[
                  const SizedBox(height: 15),
                  Text(
                    'Next recommended difficulty: '
                    '$nextDifficulty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 25),

        SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _startNewGame,
            icon: const Icon(
              Icons.refresh,
              size: 28,
            ),
            label: const Text(
              'Play Again',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height: 55,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 70,
            ),

            const SizedBox(height: 20),

            const Text(
              'Unable to start the game',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _startNewGame,
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}