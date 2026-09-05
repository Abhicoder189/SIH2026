import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

enum VoiceLanguage {
  english(
    code: 'en',
    sttLocale: 'en_IN',
    ttsLocale: 'en-IN',
    name: 'English',
  ),
  hindi(
    code: 'hi',
    sttLocale: 'hi_IN',
    ttsLocale: 'hi-IN',
    name: 'हिन्दी',
  ),
  assamese(
    code: 'as',
    sttLocale: 'as_IN',
    ttsLocale: 'as-IN',
    name: 'অসমীয়া',
  ),
  bengali(
    code: 'bn',
    sttLocale: 'bn_IN',
    ttsLocale: 'bn-IN',
    name: 'বাংলা',
  ),
  nepali(
    code: 'ne',
    sttLocale: 'ne_NP',
    ttsLocale: 'ne-NP',
    name: 'नेपाली',
  ),
  bodo(
    code: 'brx',
    sttLocale: 'brx_IN',
    ttsLocale: 'brx-IN',
    name: 'बड़ो',
  ),
  manipuri(
    code: 'mni',
    sttLocale: 'mni_IN',
    ttsLocale: 'mni-IN',
    name: 'মৈতৈলোন',
  ),
  khasi(
    code: 'kha',
    sttLocale: 'kha_IN',
    ttsLocale: 'kha-IN',
    name: 'Khasi',
  ),
  mizo(
    code: 'lus',
    sttLocale: 'lus_IN',
    ttsLocale: 'lus-IN',
    name: 'Mizo',
  ),
  kokborok(
    code: 'trp',
    sttLocale: 'trp_IN',
    ttsLocale: 'trp-IN',
    name: 'Kokborok',
  );

  const VoiceLanguage({
    required this.code,
    required this.sttLocale,
    required this.ttsLocale,
    required this.name,
  });

  final String code;
  final String sttLocale;
  final String ttsLocale;
  final String name;
}

class LanguageService {
  static const String _appLanguageKey = 'app_language';
  static const String _voiceLanguageKey = 'voice_language';

  // ------------------------------------------------------------
  // APP LANGUAGE
  // ------------------------------------------------------------

  static Future<AppLanguage> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCode = prefs.getString(_appLanguageKey);

    if (savedCode == null || savedCode.isEmpty) {
      return AppLanguage.english;
    }

    for (final language in AppLanguage.values) {
      if (language.code == savedCode) {
        return language;
      }
    }

    return AppLanguage.english;
  }

  static Future<void> saveLanguage(
    AppLanguage language,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _appLanguageKey,
      language.code,
    );
  }

  // ------------------------------------------------------------
  // VOICE LANGUAGE
  // ------------------------------------------------------------

  // Kept with these names because VoiceAssistantScreen
  // already uses them.
  static const VoiceLanguage defaultLanguage =
      VoiceLanguage.english;

  static const List<VoiceLanguage> supportedLanguages = [
    VoiceLanguage.english,
    VoiceLanguage.hindi,
    VoiceLanguage.assamese,
    VoiceLanguage.bengali,
    VoiceLanguage.nepali,
    VoiceLanguage.bodo,
    VoiceLanguage.manipuri,
    VoiceLanguage.khasi,
    VoiceLanguage.mizo,
    VoiceLanguage.kokborok,
  ];

  static Future<VoiceLanguage> getVoiceLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCode = prefs.getString(_voiceLanguageKey);

    if (savedCode == null || savedCode.isEmpty) {
      return defaultLanguage;
    }

    for (final language in supportedLanguages) {
      if (language.code == savedCode) {
        return language;
      }
    }

    return defaultLanguage;
  }

  static Future<void> saveVoiceLanguage(
    VoiceLanguage language,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _voiceLanguageKey,
      language.code,
    );
  }

  static VoiceLanguage fromCode(String code) {
    for (final language in supportedLanguages) {
      if (language.code == code) {
        return language;
      }
    }

    return defaultLanguage;
  }

  static Future<VoiceLanguage> getCurrentVoiceLanguage() async {
    return getVoiceLanguage();
  }

  static Future<bool> hasSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final appLanguage = prefs.getString(_appLanguageKey);
    final voiceLanguage = prefs.getString(_voiceLanguageKey);

    return (appLanguage != null && appLanguage.isNotEmpty) ||
        (voiceLanguage != null && voiceLanguage.isNotEmpty);
  }

  static Future<void> clearLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_appLanguageKey);
    await prefs.remove(_voiceLanguageKey);
  }
}