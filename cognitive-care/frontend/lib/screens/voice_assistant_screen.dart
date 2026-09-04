
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import 'attention_game_screen.dart';
import 'memory_game_screen.dart';
import 'pattern_game_screen.dart';
import 'notification_feed_screen.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({
    super.key,
    required this.token,
    required this.patientId,
  });

  final String token;
  final String patientId;

  @override
  State<VoiceAssistantScreen> createState() =>
      _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState
    extends State<VoiceAssistantScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _speechAvailable = false;

  String _recognizedText = '';
  String _responseText = 'Tap the microphone and speak.';

  final List<Map<String, String>> _conversationHistory = [];

  VoiceLanguage _selectedLanguage =
      LanguageService.defaultLanguage;

  List<stt.LocaleName> _availableLocales = [];

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;

        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
          _responseText =
              'I could not hear you. Please try again.';
        });
      },
    );

    if (!mounted) return;

    _availableLocales = await _speech.locales();

    setState(() {
      _speechAvailable = available;
    });

    await _setTtsLanguage();
  }

  Future<void> _setTtsLanguage() async {
    try {
      await _tts.setLanguage(_selectedLanguage.ttsLocale);
    } catch (_) {
      await _tts.setLanguage('en-IN');
    }
  }

  String _getBestSttLocale() {
    final requested = _selectedLanguage.sttLocale;

    for (final locale in _availableLocales) {
      if (locale.localeId.toLowerCase() ==
          requested.toLowerCase()) {
        return locale.localeId;
      }
    }

    final languageCode =
        requested.split('_').first.toLowerCase();

    for (final locale in _availableLocales) {
      if (locale.localeId
          .toLowerCase()
          .startsWith(languageCode)) {
        return locale.localeId;
      }
    }

    return 'en_IN';
  }

  Future<void> _selectLanguage(VoiceLanguage language) async {
    if (_isListening || _isProcessing) return;

    setState(() {
      _selectedLanguage = language;
      _recognizedText = '';
    });

    await _setTtsLanguage();

    final requestedLocale = language.sttLocale;
    final actualLocale = _getBestSttLocale();

    if (!_availableLocales.any(
      (locale) =>
          locale.localeId.toLowerCase() ==
          requestedLocale.toLowerCase(),
    )) {
      setState(() {
        _responseText =
            '${language.name} voice recognition is not '
            'available on this device. Using $actualLocale '
            'instead.';
      });
    } else {
      setState(() {
        _responseText =
            '${language.name} selected. Tap the microphone '
            'and speak.';
      });
    }
  }

 Future<void> _startListening() async {
  if (_isProcessing || _isListening) return;

  if (!_speechAvailable) {
    setState(() {
      _responseText =
          'Speech recognition is not available on this device.';
    });
    return;
  }

  final locale = _getBestSttLocale();

  setState(() {
    _isListening = true;
    _recognizedText = '';
    _responseText =
        'Listening in ${_selectedLanguage.name}...';
  });

  await _speech.listen(
    listenOptions: stt.SpeechListenOptions(
      localeId: locale,
      listenMode: stt.ListenMode.confirmation,
    ),
    onResult: (result) {
      if (!mounted) return;

      setState(() {
        _recognizedText = result.recognizedWords;
      });

      if (result.finalResult &&
          result.recognizedWords.trim().isNotEmpty) {
        _processCommand(result.recognizedWords);
      }
    },
  );
} Future<void> _stopListening() async {
    await _speech.stop();

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _processCommand(String text) async {
    if (_isProcessing) return;

    final cleanText = text.trim();

    if (cleanText.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _responseText = 'Processing...';
    });

    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please log in again.');
      }

      final history =
          List<Map<String, String>>.from(
        _conversationHistory,
      );

      final result = await ApiService.voiceCommand(
        token,
        cleanText,
        language: _selectedLanguage.code,
        history: history,
      );

      final intent =
          result['intent']?.toString() ?? 'unknown';

      final response =
          result['response']?.toString() ??
              'I did not understand that.';

      final responseLanguage =
          result['language']?.toString() ??
              _selectedLanguage.code;

      // Save the conversation after Gemini has interpreted
      // the current request.
      _conversationHistory.add({
        'role': 'user',
        'content': cleanText,
      });

      _conversationHistory.add({
        'role': 'assistant',
        'content': response,
      });

      // Keep the last 5 exchanges = 10 messages.
      while (_conversationHistory.length > 10) {
        _conversationHistory.removeAt(0);
      }

      if (!mounted) return;

      setState(() {
        _recognizedText = cleanText;
        _responseText = response;
      });

      await _tts.stop();

      final languageForTts =
          _getTtsLocale(responseLanguage);

      try {
        await _tts.setLanguage(languageForTts);
      } catch (_) {
        await _setTtsLanguage();
      }

      await _tts.speak(response);

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      await _handleIntent(intent);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _responseText =
            'Something went wrong. Please try again.';
      });

      await _tts.stop();
      await _setTtsLanguage();

      await _tts.speak(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _getTtsLocale(String language) {
    switch (language.toLowerCase()) {
      case 'hi':
        return 'hi-IN';

      case 'bn':
        return 'bn-IN';

      case 'as':
        return 'as-IN';

      case 'mni':
        return 'mni-IN';

      case 'lus':
        return 'lus-IN';

      case 'kha':
        return 'kha-IN';

      case 'grt':
        return 'grt-IN';

      case 'trp':
        return 'trp-IN';

      case 'nag':
        return 'nag-IN';

      case 'en':
      default:
        return 'en-IN';
    }
  }

  Future<void> _handleIntent(String intent) async {
    switch (intent) {
      case 'start_memory':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemoryGameScreen(
              patientId: widget.patientId,
              token: widget.token,
            ),
          ),
        );
        break;

      case 'start_attention':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttentionGameScreen(
              patientId: widget.patientId,
              token: widget.token,
            ),
          ),
        );
        break;

      case 'start_pattern':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatternGameScreen(
              patientId: widget.patientId,
              token: widget.token,
            ),
          ),
        );
        break;

      case 'read_reminders':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationFeedScreen(
              patientId: widget.patientId,
              token: widget.token,
            ),
          ),
        );
        break;

      case 'help':
      case 'repeat':
      case 'unknown':
      default:
        break;
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voice Assistant',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.record_voice_over,
                  size: 90,
                ),

                const SizedBox(height: 25),

                const Text(
                  'Voice Assistant',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose language',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<VoiceLanguage>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                  items: LanguageService.supportedLanguages
                      .map(
                        (language) =>
                            DropdownMenuItem<VoiceLanguage>(
                          value: language,
                          child: Text(language.name),
                        ),
                      )
                      .toList(),
                  onChanged: (language) {
                    if (language != null) {
                      _selectLanguage(language);
                    }
                  },
                ),

                const SizedBox(height: 25),

                Text(
                  'Try saying:',
                  style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _selectedLanguage.code == 'hi'
                      ? '"मेमोरी गेम शुरू करो"\n'
                          '"ध्यान गेम शुरू करो"\n'
                          '"पैटर्न गेम शुरू करो"\n'
                          '"मेरे रिमाइंडर दिखाओ"'
                      : '"Play memory"\n'
                          '"Play attention"\n'
                          '"Play pattern"\n'
                          '"Show my reminders"',
                  style: const TextStyle(
                    fontSize: 19,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                if (_recognizedText.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'You said:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recognizedText,
                            style: const TextStyle(
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Assistant:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _responseText,
                          style: const TextStyle(
                            fontSize: 20,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                GestureDetector(
                  onTap: _isListening
                      ? _stopListening
                      : _startListening,
                  child: CircleAvatar(
                    radius: 45,
                    child: Icon(
                      _isListening
                          ? Icons.stop
                          : Icons.mic,
                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  _isListening
                      ? 'Tap to stop'
                      : 'Tap to speak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (_isProcessing) ...[
                  const SizedBox(height: 25),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

