class VoiceLanguage {
  final String name;
  final String code;
  final String sttLocale;
  final String ttsLocale;

  const VoiceLanguage({
    required this.name,
    required this.code,
    required this.sttLocale,
    required this.ttsLocale,
  });
}

class LanguageService {
  static const List<VoiceLanguage> supportedLanguages = [
    VoiceLanguage(
      name: 'English',
      code: 'en',
      sttLocale: 'en_IN',
      ttsLocale: 'en-IN',
    ),
    VoiceLanguage(
      name: 'Hindi',
      code: 'hi',
      sttLocale: 'hi_IN',
      ttsLocale: 'hi-IN',
    ),
    VoiceLanguage(
      name: 'Assamese',
      code: 'as',
      sttLocale: 'as_IN',
      ttsLocale: 'as-IN',
    ),
    VoiceLanguage(
      name: 'Bengali',
      code: 'bn',
      sttLocale: 'bn_IN',
      ttsLocale: 'bn-IN',
    ),
    VoiceLanguage(
      name: 'Manipuri',
      code: 'mni',
      sttLocale: 'mni_IN',
      ttsLocale: 'mni-IN',
    ),
    VoiceLanguage(
      name: 'Mizo',
      code: 'lus',
      sttLocale: 'lus_IN',
      ttsLocale: 'lus-IN',
    ),
    VoiceLanguage(
      name: 'Khasi',
      code: 'kha',
      sttLocale: 'kha_IN',
      ttsLocale: 'kha-IN',
    ),
    VoiceLanguage(
      name: 'Garo',
      code: 'grt',
      sttLocale: 'grt_IN',
      ttsLocale: 'grt-IN',
    ),
    VoiceLanguage(
      name: 'Tripuri',
      code: 'trp',
      sttLocale: 'trp_IN',
      ttsLocale: 'trp-IN',
    ),
    VoiceLanguage(
      name: 'Nagamese',
      code: 'nag',
      sttLocale: 'nag_IN',
      ttsLocale: 'nag-IN',
    ),
  ];

  static VoiceLanguage get defaultLanguage => supportedLanguages.first;

  static VoiceLanguage? findByCode(String code) {
    for (final language in supportedLanguages) {
      if (language.code == code) {
        return language;
      }
    }

    return null;
  }
}