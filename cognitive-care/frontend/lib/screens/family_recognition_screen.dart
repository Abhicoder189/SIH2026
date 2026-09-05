import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/api_service.dart';

class FamilyRecognitionScreen extends StatefulWidget {
  final String token;
  final String patientId;

  const FamilyRecognitionScreen({
    super.key,
    required this.token,
    required this.patientId,
  });

  @override
  State<FamilyRecognitionScreen> createState() =>
      _FamilyRecognitionScreenState();
}

class _FamilyRecognitionScreenState
    extends State<FamilyRecognitionScreen> {
  List<dynamic> _members = [];
  bool _loading = true;
  String? _error;
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
      final result = await ApiService.listFamilyMembers(
        widget.token,
        patientId: widget.patientId,
      );

      if (!mounted) return;

      final members = result['family_members'];

      setState(() {
        _members = members is List
            ? members.map((m) => Map<String, dynamic>.from(m)).toList()
            : [];
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

  Future<void> _speak(String text) async {
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  void _showMemberDetail(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    final relationship = member['relationship']?.toString() ?? '';
    final description = member['description']?.toString() ?? '';
    final voiceDesc = member['voice_description']?.toString() ?? '';
    final photoUrl = member['photo_url']?.toString() ?? '';
    final nicknames = member['nicknames'];
    final howYouKnow = member['how_you_know_them']?.toString() ?? '';
    final funFact = member['fun_fact']?.toString() ?? '';

    bool hasPhoto = photoUrl.isNotEmpty;

    final speakText = voiceDesc.isNotEmpty
        ? voiceDesc
        : 'This is $name. $relationship. $description';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.teal.shade50,
                backgroundImage: hasPhoto
                    ? MemoryImage(base64Decode(photoUrl))
                    : null,
                child: !hasPhoto
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                relationship,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, height: 1.4),
                ),
              ],
              if (nicknames is List && nicknames.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: nicknames.map((n) => Chip(
                    label: Text(n.toString(), style: const TextStyle(fontSize: 13)),
                    backgroundColor: Colors.orange.shade50,
                  )).toList(),
                ),
              ],
              if (howYouKnow.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.history_edu, size: 20, color: Colors.blue.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        howYouKnow,
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
              if (funFact.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.celebration, size: 20, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        funFact,
                        style: TextStyle(fontSize: 15, color: Colors.amber.shade800),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _speak(speakText);
            },
            icon: const Icon(Icons.volume_up, size: 24),
            label: const Text('LISTEN', style: TextStyle(fontSize: 17)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'My Family',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : _members.isEmpty
                  ? _emptyBody()
                  : _listBody(),
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Please try again.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN', style: TextStyle(fontSize: 18)),
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
            Icon(Icons.people_outline, size: 80, color: Colors.teal.shade200),
            const SizedBox(height: 20),
            const Text(
              'No family members added yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your caregiver will add photos and information '
              'about your family members here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          Center(
            child: Text(
              'TAP A PHOTO TO LEARN MORE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._members.map((m) => _memberCard(m)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    final relationship = member['relationship']?.toString() ?? '';
    final photoUrl = member['photo_url']?.toString() ?? '';
    final description = member['description']?.toString() ?? '';

    bool hasPhoto = photoUrl.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMemberDetail(member),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.teal.shade50,
                backgroundImage: hasPhoto
                    ? MemoryImage(base64Decode(photoUrl))
                    : null,
                child: !hasPhoto
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relationship,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
}
