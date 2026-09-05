import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/api_service.dart';

class MemoryMomentScreen extends StatefulWidget {
  final String token;
  final String patientId;

  const MemoryMomentScreen({
    super.key,
    required this.token,
    required this.patientId,
  });

  @override
  State<MemoryMomentScreen> createState() =>
      _MemoryMomentScreenState();
}

class _MemoryMomentScreenState extends State<MemoryMomentScreen> {
  Map<String, dynamic>? _memory;
  bool _loading = true;
  String? _error;
  bool _speaking = false;

  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.getTodayMemory(
        widget.token,
        widget.patientId,
      );

      if (!mounted) return;

      final memory = result['memory'];

      setState(() {
        _memory = memory is Map
            ? Map<String, dynamic>.from(memory)
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _speak() async {
    if (_memory == null || _speaking) return;

    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    final text = _buildSpeakText();

    if (mounted) {
      setState(() {
        _speaking = true;
      });
    }

    await _tts.speak(text);

    if (mounted) {
      setState(() {
        _speaking = false;
      });
    }

    try {
      await ApiService.memoryInteraction(
        token: widget.token,
        memoryId: _memory!['id']?.toString() ?? '',
        action: 'listened',
      );
    } catch (_) {}
  }

  String _buildSpeakText() {
    if (_memory == null) return '';

    final title = _memory!['title']?.toString() ?? '';
    final description = _memory!['description']?.toString() ?? '';
    final place = _memory!['place']?.toString() ?? '';
    final year = _memory!['year'];
    final people = _memory!['people'];

    final buffer = StringBuffer();
    buffer.write('A memory from your life. ');
    buffer.write('$title. ');

    if (description.isNotEmpty) {
      buffer.write('$description ');
    }

    if (place.isNotEmpty && year != null) {
      buffer.write('This was in $place, in $year. ');
    } else if (place.isNotEmpty) {
      buffer.write('This was in $place. ');
    } else if (year != null) {
      buffer.write('This was in $year. ');
    }

    if (people is List && people.isNotEmpty) {
      final names = people.map((p) => p.toString()).toList();
      if (names.length == 1) {
        buffer.write('With ${names.first}. ');
      } else if (names.length == 2) {
        buffer.write('With ${names[0]} and ${names[1]}. ');
      } else {
        final last = names.removeLast();
        buffer.write('With ${names.join(", ")}, and $last. ');
      }
    }

    buffer.write('You are safe. This is a beautiful memory.');

    return buffer.toString();
  }

  Future<void> _recordInteraction(String action) async {
    if (_memory == null) return;

    try {
      await ApiService.memoryInteraction(
        token: widget.token,
        memoryId: _memory!['id']?.toString() ?? '',
        action: action,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Memory Moment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'New Memory',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : _memory == null
                  ? _emptyBody()
                  : _memoryBody(),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'TRY AGAIN',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.pink.shade200,
            ),
            const SizedBox(height: 20),
            const Text(
              'No memory moment yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your caregiver can create memory moments '
              'for you. They will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'CHECK AGAIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
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

  Widget _memoryBody() {
    final title = _memory!['title']?.toString() ?? '';
    final description = _memory!['description']?.toString() ?? '';
    final place = _memory!['place']?.toString() ?? '';
    final year = _memory!['year'];
    final people = _memory!['people'];

    final peopleList = people is List
        ? people.map((p) => p.toString()).toList()
        : <String>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          Center(
            child: Icon(
              Icons.favorite,
              size: 50,
              color: Colors.pink.shade300,
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              'A MEMORY FROM YOUR LIFE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.5,
                      ),
                    ),
                  ],

                  if (place.isNotEmpty || year != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (place.isNotEmpty) ...[
                          Icon(
                            Icons.place,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            place,
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        if (place.isNotEmpty && year != null)
                          const Text(
                            ' · ',
                            style: TextStyle(fontSize: 17),
                          ),
                        if (year != null)
                          Text(
                            '$year',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (peopleList.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'People in this memory',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: peopleList.map((person) {
                        return Chip(
                          avatar: const Icon(Icons.person, size: 18),
                          label: Text(
                            person,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _speaking ? null : _speak,
              icon: _speaking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.volume_up, size: 26),
              label: Text(
                _speaking ? 'LISTENING...' : 'LISTEN TO THIS MEMORY',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _recordInteraction('next');
                await _load();
              },
              icon: const Icon(Icons.arrow_forward, size: 24),
              label: const Text(
                'NEXT MEMORY',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'These are memories saved by your caregiver. '
                'They help you remember the important people '
                'and moments in your life.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
