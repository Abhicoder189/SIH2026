import 'package:flutter/material.dart';

import '../services/api_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key, required this.token});

  final String token;

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final controller = TextEditingController();
  String response = 'Type a request, for example: "Start memory game".';

  Future<void> _send() async {
    try {
      final result = await ApiService.voiceCommand(widget.token, controller.text);
      if (mounted) setState(() => response = result['response'] as String);
    } catch (error) {
      if (mounted) {
        setState(() => response = error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.record_voice_over, size: 90),
            const SizedBox(height: 20),
            Text(
              response,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22),
            ),
            const Spacer(),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Your request',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 20),
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send),
                label: const Text('ASK', style: TextStyle(fontSize: 21)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
