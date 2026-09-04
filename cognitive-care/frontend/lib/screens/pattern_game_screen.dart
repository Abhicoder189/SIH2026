import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PatternGameScreen extends StatefulWidget {
  final String patientId;
  final String token;

  const PatternGameScreen({
    super.key,
    required this.patientId,
    required this.token,
  });

  @override
  State<PatternGameScreen> createState() => _PatternGameScreenState();
}

class _PatternGameScreenState extends State<PatternGameScreen> {
  bool _loading = true;
  bool _submitting = false;
  bool _gameFinished = false;

  String? _sessionId;
  List<String> _pattern = [];
  List<String> _options = [];

  String? _selectedAnswer;
  String? _correctAnswer;

  double _reactionTime = 0;
  DateTime? _questionStartTime;

  int _score = 0;
  int _nextDifficulty = 1;

  String? _error;

  final List<String> _allSymbols = [
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
  ];

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  Future<void> _startGame() async {
    setState(() {
      _loading = true;
      _submitting = false;
      _gameFinished = false;
      _selectedAnswer = null;
      _correctAnswer = null;
      _error = null;
      _pattern = [];
      _options = [];
    });

    try {
      final response = await ApiService.startPatternGame(
        patientId: widget.patientId,
        difficulty: 1,
        token: widget.token,
      );

      final challenge = response['challenge'];

      final pattern = List<String>.from(
        challenge['pattern'] ?? [],
      );

      if (pattern.isEmpty) {
        throw Exception('Pattern data is empty');
      }

      // The backend's pattern follows a repeating sequence.
      // The missing answer is the next expected element.
      final correctAnswer = _calculateAnswer(pattern);

      final options = _generateOptions(
        correctAnswer,
        pattern,
      );

      setState(() {
        _sessionId = response['game_session_id'];
        _pattern = pattern;
        _correctAnswer = correctAnswer;
        _options = options;
        _nextDifficulty =
            response['difficulty'] ?? 1;
        _loading = false;
        _questionStartTime = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _calculateAnswer(List<String> pattern) {
    if (pattern.length < 2) {
      return pattern.last;
    }

    // Find the smallest repeating cycle.
    for (int cycleLength = 1;
        cycleLength <= pattern.length ~/ 2;
        cycleLength++) {
      bool valid = true;

      for (int i = cycleLength;
          i < pattern.length;
          i++) {
        if (pattern[i] != pattern[i % cycleLength]) {
          valid = false;
          break;
        }
      }

      if (valid) {
        return pattern[pattern.length % cycleLength];
      }
    }

    // Fallback for non-perfectly repeating patterns.
    return pattern[pattern.length - 1];
  }

  List<String> _generateOptions(
    String correctAnswer,
    List<String> pattern,
  ) {
    final options = <String>[correctAnswer];

    final candidates = _allSymbols
        .where((symbol) => symbol != correctAnswer)
        .toList();

    candidates.shuffle();

    for (final candidate in candidates) {
      if (options.length >= 4) {
        break;
      }

      options.add(candidate);
    }

    options.shuffle();

    return options;
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null ||
        _sessionId == null ||
        _submitting) {
      return;
    }

    final endTime = DateTime.now();

    if (_questionStartTime != null) {
      _reactionTime =
          endTime.difference(_questionStartTime!).inMilliseconds /
              1000.0;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final response = await ApiService.submitGame(
  gameType: 'pattern',
  patientId: widget.patientId,
  sessionId: _sessionId!,
  answer: _selectedAnswer!,
  reactionTime: _reactionTime,
  hintsUsed: 0,
  token: widget.token,

      );

      setState(() {
        _score = ((response['score'] ?? 0) as num).toInt();

        _nextDifficulty =
            ((response['next_difficulty'] ?? 1) as num).toInt();

        _gameFinished = true;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  Color _optionColor(String option) {
    if (!_gameFinished) {
      if (_selectedAnswer == option) {
        return Colors.blue.shade100;
      }

      return Colors.white;
    }

    if (option == _correctAnswer) {
      return Colors.green.shade100;
    }

    if (option == _selectedAnswer) {
      return Colors.red.shade100;
    }

    return Colors.white;
  }

  IconData? _optionIcon(String option) {
    if (!_gameFinished) {
      return null;
    }

    if (option == _correctAnswer) {
      return Icons.check_circle;
    }

    if (option == _selectedAnswer) {
      return Icons.cancel;
    }

    return null;
  }

  String _resultMessage() {
    if (_score == 100) {
      return 'Excellent! 🎉';
    }

    if (_score >= 50) {
      return 'Good effort! 👍';
    }

    return 'Keep practicing! 💪';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pattern Game',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_gameFinished) {
      return _buildResult();
    }

    return _buildGame();
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
              'What comes next?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              'Look at the pattern and select the missing item.',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 35),

            _buildPattern(),

            const SizedBox(height: 40),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose the answer:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),

            _buildOptions(),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed:
                    _selectedAnswer == null || _submitting
                        ? null
                        : _submitAnswer,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : const Text(
                        'SUBMIT ANSWER',
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

  Widget _buildPattern() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 25,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._pattern.map(
              (symbol) => _buildPatternItem(symbol),
            ),
            _buildMissingItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternItem(String symbol) {
    return Container(
      width: 65,
      height: 65,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.blue.shade50,
        border: Border.all(
          color: Colors.blue.shade300,
          width: 2,
        ),
      ),
      child: Text(
        symbol,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMissingItem() {
    return Container(
      width: 65,
      height: 65,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange,
          width: 3,
        ),
      ),
      child: const Text(
        '?',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _options.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        final option = _options[index];
        final selected = _selectedAnswer == option;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _gameFinished
              ? null
              : () {
                  setState(() {
                    _selectedAnswer = option;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _optionColor(option),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Colors.blue
                    : Colors.grey.shade300,
                width: selected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: selected ? 6 : 2,
                  color: Colors.black12,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  option,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_optionIcon(option) != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _optionIcon(option),
                    size: 28,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult() {
    final correct = _score == 100;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              correct
                  ? Icons.celebration
                  : Icons.psychology,
              size: 80,
              color: correct
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
              'Reaction time: ${_reactionTime.toStringAsFixed(1)} seconds',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Next recommended difficulty: $_nextDifficulty',
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
}