import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AttentionGameScreen extends StatefulWidget {
  final String patientId;
  final String token;

  const AttentionGameScreen({
    super.key,
    required this.patientId,
    required this.token,
  });

  @override
  State<AttentionGameScreen> createState() =>
      _AttentionGameScreenState();
}

class _AttentionGameScreenState
    extends State<AttentionGameScreen> {
  bool _loading = true;
  bool _submitting = false;
  bool _finished = false;

  String? _sessionId;
  String? _target;

  List<String> _grid = [];
  int _correctCount = 0;
  int _selectedCount = 0;
  int _score = 0;
  int _nextDifficulty = 1;

  DateTime? _startTime;
  double _reactionTime = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  Future<void> _startGame() async {
    setState(() {
      _loading = true;
      _submitting = false;
      _finished = false;
      _error = null;
      _selectedCount = 0;
      _score = 0;
      _grid = [];
    });

    try {
      final response = await ApiService.startGame(
        gameType: 'attention',
        patientId: widget.patientId,
        difficulty: 1,
        token: widget.token,
      );

      final challenge = response['challenge'];

      final grid = List<String>.from(
        challenge['grid'] ?? [],
      );

      final target = challenge['target']?.toString();

      if (grid.isEmpty || target == null) {
        throw Exception(
          'Invalid attention game data received from server',
        );
      }

      setState(() {
        _sessionId =
            response['game_session_id']?.toString();

        _grid = grid;
        _target = target;

        _correctCount =
            (challenge['correct_count'] as num?)?.toInt() ?? 0;

        _nextDifficulty =
            (response['difficulty'] as num?)?.toInt() ?? 1;

        _loading = false;
        _startTime = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _selectSymbol(String symbol) {
    if (_finished || _submitting) {
      return;
    }

    if (symbol == _target) {
      setState(() {
        _selectedCount++;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_sessionId == null || _submitting) {
      return;
    }

    if (_startTime != null) {
      _reactionTime =
          DateTime.now()
                  .difference(_startTime!)
                  .inMilliseconds /
              1000.0;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final response = await ApiService.submitGame(
        gameType: 'attention',
        patientId: widget.patientId,
        sessionId: _sessionId!,
        answer: _selectedCount,
        reactionTime: _reactionTime,
        hintsUsed: 0,
        token: widget.token,
      );

      setState(() {
        _score =
            (response['score'] as num?)?.toInt() ?? 0;

        _nextDifficulty =
            (response['next_difficulty'] as num?)?.toInt() ??
                1;

        _finished = true;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  String _symbolToEmoji(String symbol) {
    switch (symbol.toLowerCase()) {
      case 'circle':
        return '🔵';
      case 'square':
        return '🟩';
      case 'triangle':
        return '🔺';
      case 'star':
        return '⭐';
      default:
        return symbol;
    }
  }

  String _resultMessage() {
    if (_score == 100) {
      return 'Excellent! 🎉';
    }

    if (_score >= 50) {
      return 'Good job! 👍';
    }

    return 'Keep practicing! 💪';
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 70,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startGame,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            const Text(
              'Attention Game',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Count how many target symbols you can find.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),

            const SizedBox(height: 25),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Find:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _symbolToEmoji(_target ?? ''),
                      style: const TextStyle(
                        fontSize: 55,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Selected: $_selectedCount',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount: _grid.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final symbol = _grid[index];
                final isTarget = symbol == _target;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _selectSymbol(symbol);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _symbolToEmoji(symbol),
                        style: const TextStyle(
                          fontSize: 36,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed:
                    _submitting ? null : _submitAnswer,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : const Text(
                        'SUBMIT',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final difference =
        (_selectedCount - _correctCount).abs();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              _score == 100
                  ? Icons.celebration
                  : Icons.psychology,
              size: 80,
              color: _score == 100
                  ? Colors.green
                  : Colors.orange,
            ),

            const SizedBox(height: 20),

            Text(
              _resultMessage(),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Score: $_score%',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Your answer: $_selectedCount',
              style: const TextStyle(fontSize: 18),
            ),

            Text(
              'Correct answer: $_correctCount',
              style: const TextStyle(fontSize: 18),
            ),

            if (difference > 0)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8),
                child: Text(
                  'You were $difference away.',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            Text(
              'Reaction time: '
              '${_reactionTime.toStringAsFixed(1)} seconds',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Next recommended difficulty: '
              '$_nextDifficulty',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _startGame,
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'BACK HOME',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Attention Game',
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
              ? _buildError()
              : _finished
                  ? _buildResult()
                  : _buildGame(),
    );
  }
}