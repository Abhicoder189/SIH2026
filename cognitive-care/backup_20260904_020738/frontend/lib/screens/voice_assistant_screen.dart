import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key, required this.token});
  final String token;
  @override State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final _controller = TextEditingController();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _listening = false, _busy = false;
  String _response = 'Tap the microphone and speak, or type your request.';

  @override void dispose() { _controller.dispose(); _tts.stop(); super.dispose(); }

  Future<void> _toggleListening() async {
    if (_listening) { await _speech.stop(); if (mounted) setState(() => _listening = false); return; }
    final ok = await _speech.initialize(onStatus: (s) { if (s == 'done' && mounted) setState(() => _listening = false); });
    if (!ok) { _show('Speech recognition is unavailable on this device/browser.'); return; }
    if (mounted) setState(() => _listening = true);
    await _speech.listen(onResult: (r) { _controller.text = r.recognizedWords; if (r.finalResult) _send(); });
  }

  Future<void> _send() async {
    final text = _controller.text.trim(); if (text.isEmpty || _busy) return;
    if (mounted) setState(() => _busy = true);
    try {
      final result = await ApiService.voiceCommand(widget.token, text);
      final reply = result['response']?.toString() ?? result['message']?.toString() ?? 'I understood your request.';
      if (mounted) setState(() { _response = reply; _busy = false; });
      await _tts.speak(reply);
    } catch (e) {
      if (mounted) setState(() { _response = e.toString().replaceFirst('Exception: ', ''); _busy = false; });
    }
  }
  void _show(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Voice Help')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650), child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.record_voice_over, size: 88), const SizedBox(height: 24),
        Text(_response, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, height: 1.4)),
        const SizedBox(height: 30),
        TextField(controller: _controller, minLines: 1, maxLines: 3, style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(labelText: 'What do you need?', border: OutlineInputBorder())),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: SizedBox(height: 58, child: ElevatedButton.icon(
          onPressed: _toggleListening, icon: Icon(_listening ? Icons.stop : Icons.mic),
          label: Text(_listening ? 'STOP LISTENING' : 'SPEAK', style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 12), Expanded(child: SizedBox(height: 58, child: ElevatedButton.icon(
            onPressed: _busy ? null : _send, icon: const Icon(Icons.send), label: const Text('ASK', style: TextStyle(fontSize: 18)))))]),
      ]),
    )))
  );
}
