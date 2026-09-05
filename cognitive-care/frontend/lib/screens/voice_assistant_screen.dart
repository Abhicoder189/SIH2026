import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../l10n/language_service.dart';

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
  bool _ttsAvailable = false;

  String _recognizedText = '';
  String _responseText = 'Tap the microphone and speak.';

  final List<Map<String, String>> _conversationHistory = [];

  VoiceLanguage _selectedLanguage =
      LanguageService.defaultLanguage;

  List<stt.LocaleName> _availableLocales = [];
  List<String> _availableTtsLanguages = [];

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    final savedLanguage =
        await LanguageService.getVoiceLanguage();

    final speechAvailable = await _speech.initialize(
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

    final speechLocales = await _speech.locales();

    List<String> ttsLanguages = [];

    try {
      final languages = await _tts.getLanguages;

      if (languages is List) {
        ttsLanguages = languages
            .map((language) => language.toString())
            .toList();
      }
    } catch (_) {
      ttsLanguages = [];
    }

    if (!mounted) return;

    setState(() {
      _selectedLanguage = savedLanguage;
      _availableLocales = speechLocales;
      _availableTtsLanguages = ttsLanguages;
      _speechAvailable = speechAvailable;
    });

    await _configureSelectedLanguage(showMessage: false);
  }

  String _normalizeLocale(String locale) {
    return locale
        .trim()
        .replaceAll('_', '-')
        .toLowerCase();
  }

  bool _localeMatches(
    String available,
    String requested,
  ) {
    final a = _normalizeLocale(available);
    final r = _normalizeLocale(requested);

    if (a == r) {
      return true;
    }

    return a.split('-').first == r.split('-').first;
  }

  bool _isTtsLanguageAvailable(String locale) {
    if (_availableTtsLanguages.isEmpty) {
      return false;
    }

    return _availableTtsLanguages.any(
      (available) => _localeMatches(
        available,
        locale,
      ),
    );
  }

  String? _getAvailableTtsLocale() {
    final requested = _selectedLanguage.ttsLocale;

    for (final language in _availableTtsLanguages) {
      if (_normalizeLocale(language) ==
          _normalizeLocale(requested)) {
        return language;
      }
    }

    for (final language in _availableTtsLanguages) {
      if (_localeMatches(
        language,
        requested,
      )) {
        return language;
      }
    }

    return null;
  }

  Future<bool> _setTtsLanguage() async {
    final requestedLocale =
        _selectedLanguage.ttsLocale;

    if (!_isTtsLanguageAvailable(requestedLocale)) {
      if (mounted) {
        setState(() {
          _ttsAvailable = false;
        });
      }

      return false;
    }

    final actualLocale =
        _getAvailableTtsLocale();

    if (actualLocale == null) {
      if (mounted) {
        setState(() {
          _ttsAvailable = false;
        });
      }

      return false;
    }

    try {
      await _tts.setLanguage(actualLocale);

      if (mounted) {
        setState(() {
          _ttsAvailable = true;
        });
      }

      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _ttsAvailable = false;
        });
      }

      return false;
    }
  }

  String? _getBestSttLocale() {
    if (_availableLocales.isEmpty) {
      return null;
    }

    final requested =
        _selectedLanguage.sttLocale;

    for (final locale in _availableLocales) {
      if (_normalizeLocale(locale.localeId) ==
          _normalizeLocale(requested)) {
        return locale.localeId;
      }
    }

    for (final locale in _availableLocales) {
      if (_localeMatches(
        locale.localeId,
        requested,
      )) {
        return locale.localeId;
      }
    }

    return null;
  }

  bool _isSttLanguageAvailable() {
    return _getBestSttLocale() != null;
  }

  Future<void> _configureSelectedLanguage({
    bool showMessage = true,
  }) async {
    final sttAvailable =
        _isSttLanguageAvailable();

    final ttsAvailable =
        await _setTtsLanguage();

    if (!mounted || !showMessage) return;

    if (!sttAvailable && !ttsAvailable) {
      setState(() {
        _responseText =
            '${_selectedLanguage.name} is not available '
            'for voice input or voice output on this device.';
      });
      return;
    }

    if (!sttAvailable) {
      setState(() {
        _responseText =
            '${_selectedLanguage.name} is not available '
            'for speech recognition on this device.';
      });
      return;
    }

    if (!ttsAvailable) {
      setState(() {
        _responseText =
            '${_selectedLanguage.name} speech recognition '
            'is available, but voice output is not available '
            'on this device.';
      });
      return;
    }

    setState(() {
      _responseText =
          '${_selectedLanguage.name} selected. '
          'Tap the microphone and speak.';
    });
  }

  Future<void> _selectLanguage(
    VoiceLanguage language,
  ) async {
    if (_isListening || _isProcessing) {
      return;
    }

    setState(() {
      _selectedLanguage = language;
      _recognizedText = '';
      _responseText =
          'Checking ${language.name} voice support...';
    });

    await LanguageService.saveVoiceLanguage(
      language,
    );

    await _configureSelectedLanguage(
      showMessage: true,
    );
  }

  Future<void> _startListening() async {
    if (_isProcessing || _isListening) {
      return;
    }

    if (!_speechAvailable) {
      setState(() {
        _responseText =
            'Speech recognition is not available '
            'on this device.';
      });
      return;
    }

    final locale = _getBestSttLocale();

    if (locale == null) {
      setState(() {
        _responseText =
            '${_selectedLanguage.name} speech recognition '
            'is not available on this device.';
      });
      return;
    }

    await _setTtsLanguage();

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _responseText =
          'Listening in ${_selectedLanguage.name}...';
    });

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: locale,
          listenMode: stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _recognizedText =
                result.recognizedWords;
          });

          if (result.finalResult &&
              result.recognizedWords
                  .trim()
                  .isNotEmpty) {
            _processCommand(
              result.recognizedWords,
            );
          }
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isListening = false;
        _responseText =
            'Unable to start speech recognition. '
            'Please try again.';
      });
    }
  }

  Future<void> _stopListening() async {
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

      final result =
          await ApiService.voiceCommand(
        token,
        cleanText,
        language: _selectedLanguage.code,
        history: history,
      );

      final intent =
          result['intent']?.toString() ??
          'unknown';

      final response =
          result['response']?.toString() ??
          'I did not understand that.';

      final responseLanguage =
          result['language']?.toString() ??
          _selectedLanguage.code;

      _conversationHistory.add({
        'role': 'user',
        'content': cleanText,
      });

      _conversationHistory.add({
        'role': 'assistant',
        'content': response,
      });

      while (_conversationHistory.length > 10) {
        _conversationHistory.removeAt(0);
      }

      if (!mounted) return;

      setState(() {
        _recognizedText = cleanText;
        _responseText = response;
      });

      await _speakResponse(
        response,
        responseLanguage,
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      await _handleIntent(intent);
    } catch (_) {
      if (!mounted) return;

      final errorMessage =
          _getErrorMessage();

      setState(() {
        _responseText = errorMessage;
      });

      await _speakSelectedLanguage(
        errorMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _getErrorMessage() {
    switch (_selectedLanguage.code) {
      case 'hi':
        return 'कुछ गलत हो गया। कृपया फिर से प्रयास करें.';

      case 'bn':
        return 'কিছু ভুল হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।';

      case 'as':
        return 'কিবা ভুল হৈছে। অনুগ্ৰহ কৰি পুনৰ চেষ্টা কৰক।';

      case 'ne':
        return 'केही गलत भयो। कृपया फेरि प्रयास गर्नुहोस्।';

      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String? _getTtsLocale(String language) {
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

      case 'trp':
        return 'trp-IN';

      case 'ne':
        return 'ne-NP';

      case 'brx':
        return 'brx-IN';

      case 'en':
        return 'en-IN';

      default:
        return null;
    }
  }

  Future<void> _speakResponse(
    String response,
    String responseLanguage,
  ) async {
    await _tts.stop();

    final requestedLocale =
        _getTtsLocale(responseLanguage) ??
        _selectedLanguage.ttsLocale;

    if (!_isTtsLanguageAvailable(
      requestedLocale,
    )) {
      if (mounted) {
        setState(() {
          _ttsAvailable = false;
          _responseText =
              '$response\n\n'
              'Voice output for '
              '${_selectedLanguage.name} is not '
              'available on this device.';
        });
      }

      return;
    }

    final availableLocale =
        _getMatchingTtsLocale(
      requestedLocale,
    );

    if (availableLocale == null) {
      return;
    }

    try {
      await _tts.setLanguage(
        availableLocale,
      );

      if (mounted) {
        setState(() {
          _ttsAvailable = true;
        });
      }

      await _tts.speak(response);
    } catch (_) {
      if (mounted) {
        setState(() {
          _ttsAvailable = false;
        });
      }
    }
  }

  String? _getMatchingTtsLocale(
    String requested,
  ) {
    for (final language
        in _availableTtsLanguages) {
      if (_normalizeLocale(language) ==
          _normalizeLocale(requested)) {
        return language;
      }
    }

    for (final language
        in _availableTtsLanguages) {
      if (_localeMatches(
        language,
        requested,
      )) {
        return language;
      }
    }

    return null;
  }

  Future<void> _speakSelectedLanguage(
    String text,
  ) async {
    await _tts.stop();

    final available =
        await _setTtsLanguage();

    if (!available) return;

    try {
      await _tts.speak(text);
    } catch (_) {
      // Do not silently switch to English.
    }
  }

  Future<void> _handleIntent(
    String intent,
  ) async {
    switch (intent) {
      case 'start_memory':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MemoryGameScreen(
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
            builder: (_) =>
                AttentionGameScreen(
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
            builder: (_) =>
                PatternGameScreen(
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
            builder: (_) =>
                NotificationFeedScreen(
              patientId: widget.patientId,
              token: widget.token,
            ),
          ),
        );
        break;

      default:
        break;
    }
  }

  String _exampleCommands() {
    switch (_selectedLanguage.code) {
      case 'hi':
        return '"मेमोरी गेम शुरू करो"\n'
            '"ध्यान गेम शुरू करो"\n'
            '"पैटर्न गेम शुरू करो"\n'
            '"मेरे रिमाइंडर दिखाओ"';

      case 'bn':
        return '"মেমোরি গেম শুরু করো"\n'
            '"মনোযোগ গেম শুরু করো"\n'
            '"প্যাটার্ন গেম শুরু করো"\n'
            '"আমার রিমাইন্ডার দেখাও"';

      case 'as':
        return '"মেমৰি খেল আৰম্ভ কৰক"\n'
            '"মনোযোগ খেল আৰম্ভ কৰক"\n'
            '"আৰ্হি খেল আৰম্ভ কৰক"\n'
            '"মোৰ সোঁৱৰণী দেখুৱাওক"';

      case 'ne':
        return '"मेमोरी खेल सुरु गर्नुहोस्"\n'
            '"ध्यान खेल सुरु गर्नुहोस्"\n'
            '"प्याटर्न खेल सुरु गर्नुहोस्"\n'
            '"मेरा रिमाइन्डर देखाउनुहोस्"';

      default:
        return '"Play memory"\n'
            '"Play attention"\n'
            '"Play pattern"\n'
            '"Show my reminders"';
    }
  }

  String _supportStatus() {
    final sttSupported =
        _isSttLanguageAvailable();

    final ttsSupported = _ttsAvailable;

    if (sttSupported && ttsSupported) {
      return '${_selectedLanguage.name}: '
          'voice input ✓  voice output ✓';
    }

    if (sttSupported) {
      return '${_selectedLanguage.name}: '
          'voice input ✓  voice output unavailable';
    }

    if (ttsSupported) {
      return '${_selectedLanguage.name}: '
          'voice input unavailable  voice output ✓';
    }

    return '${_selectedLanguage.name}: '
        'voice input unavailable  voice output unavailable';
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sttSupported =
        _isSttLanguageAvailable();

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
              mainAxisAlignment:
                  MainAxisAlignment.center,
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
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<VoiceLanguage>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.language),
                  ),
                  items: LanguageService
                      .supportedLanguages
                      .map(
                        (language) =>
                            DropdownMenuItem<
                                VoiceLanguage>(
                          value: language,
                          child:
                              Text(language.name),
                        ),
                      )
                      .toList(),
                  onChanged: (language) {
                    if (language != null) {
                      _selectLanguage(language);
                    }
                  },
                ),

                const SizedBox(height: 15),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          sttSupported
                              ? Icons.mic
                              : Icons.mic_off,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _supportStatus(),
                            style:
                                const TextStyle(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Try saying:',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _exampleCommands(),
                  style: const TextStyle(
                    fontSize: 19,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                if (_recognizedText.isNotEmpty)
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'You said:',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recognizedText,
                            style:
                                const TextStyle(
                              fontSize: 20,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Assistant:',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _responseText,
                          style:
                              const TextStyle(
                            fontSize: 20,
                          ),
                          textAlign:
                              TextAlign.center,
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
                    fontWeight:
                        FontWeight.w500,
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
