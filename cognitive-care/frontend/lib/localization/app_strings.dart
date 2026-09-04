class AppStrings {
  static const supportedLanguages = [
    'English', 'Hindi', 'Assamese', 'Bengali', 'Manipuri',
    'Mizo', 'Khasi', 'Garo', 'Tripuri', 'Nagamese',
  ];

  static const _english = {
    'memory': 'Memory Game', 'pattern': 'Pattern Game', 'attention': 'Attention Game',
    'reminders': 'Reminders', 'voice': 'Voice Assistant', 'progress': 'My Progress',
    'start': 'START', 'done': 'DONE', 'later': 'REMIND ME LATER',
  };

  // English remains the safe fallback while regional translations are added
  // through reviewed language packs.
  static String text(String key, {String language = 'English'}) => _english[key] ?? key;
}
