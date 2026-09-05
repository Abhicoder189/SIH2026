import 'package:flutter/material.dart';

enum AppLanguage {
  english,
  hindi,
  assamese,
  bengali,
  nepali,
  bodo,
  manipuri,
  khasi,
  mizo,
  kokborok,
}

extension AppLanguageExtension on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.assamese:
        return 'as';
      case AppLanguage.bengali:
        return 'bn';
      case AppLanguage.nepali:
        return 'ne';
      case AppLanguage.bodo:
        return 'brx';
      case AppLanguage.manipuri:
        return 'mni';
      case AppLanguage.khasi:
        return 'kha';
      case AppLanguage.mizo:
        return 'lus';
      case AppLanguage.kokborok:
        return 'trp';
    }
  }

  Locale get locale {
    switch (this) {
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.hindi:
        return const Locale('hi');
      case AppLanguage.assamese:
        return const Locale('as');
      case AppLanguage.bengali:
        return const Locale('bn');
      case AppLanguage.nepali:
        return const Locale('ne');
      case AppLanguage.bodo:
        return const Locale('brx');
      case AppLanguage.manipuri:
        return const Locale('mni');
      case AppLanguage.khasi:
        return const Locale('kha');
      case AppLanguage.mizo:
        return const Locale('lus');
      case AppLanguage.kokborok:
        return const Locale('trp');
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hindi:
        return 'हिन्दी';
      case AppLanguage.assamese:
        return 'অসমীয়া';
      case AppLanguage.bengali:
        return 'বাংলা';
      case AppLanguage.nepali:
        return 'नेपाली';
      case AppLanguage.bodo:
        return 'बड़ो';
      case AppLanguage.manipuri:
        return 'মৈতৈলোন';
      case AppLanguage.khasi:
        return 'Khasi';
      case AppLanguage.mizo:
        return 'Mizo';
      case AppLanguage.kokborok:
        return 'Kokborok';
    }
  }
}

class AppTranslations {
  static const Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.english: {
      'app_name': 'SmiritiSarthi',
      'welcome': 'Welcome',
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'settings': 'Settings',
      'language': 'Language',
      'select_language': 'Select Language',
      'home': 'Home',
      'games': 'Games',
      'memory_game': 'Memory Game',
      'attention_game': 'Attention Game',
      'pattern_game': 'Pattern Game',
      'my_progress': 'My Progress',
      'reminders': 'Reminders',
      'voice_assistant': 'Voice Assistant',
      'notifications': 'Notifications',
      'refresh': 'Refresh',
      'start_game': 'Start Game',
      'submit': 'Submit',
      'next': 'Next',
      'cancel': 'Cancel',
      'save': 'Save',
      'back': 'Back',
      'score': 'Score',
      'accuracy': 'Accuracy',
      'performance': 'Performance',
      'difficulty': 'Difficulty',
      'easy': 'Easy',
      'medium': 'Medium',
      'hard': 'Hard',
      'loading': 'Loading...',
      'error': 'Something went wrong',
      'try_again': 'Try Again',
      'no_data': 'No data available',
      'caregiver': 'Caregiver',
      'patient': 'Patient',
      'caregiver_requests': 'Caregiver Requests',
      'no_linked_patients': 'No linked patients yet.',
    },

    AppLanguage.hindi: {
      'app_name': 'स्मृति सारथी',
      'welcome': 'स्वागत है',
      'login': 'लॉगिन',
      'logout': 'लॉगआउट',
      'register': 'पंजीकरण',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'select_language': 'भाषा चुनें',
      'home': 'होम',
      'games': 'खेल',
      'memory_game': 'स्मृति खेल',
      'attention_game': 'ध्यान खेल',
      'pattern_game': 'पैटर्न खेल',
      'my_progress': 'मेरी प्रगति',
      'reminders': 'अनुस्मारक',
      'voice_assistant': 'वॉइस असिस्टेंट',
      'notifications': 'सूचनाएँ',
      'refresh': 'रिफ्रेश',
      'start_game': 'खेल शुरू करें',
      'submit': 'जमा करें',
      'next': 'आगे',
      'cancel': 'रद्द करें',
      'save': 'सहेजें',
      'back': 'वापस',
      'score': 'स्कोर',
      'accuracy': 'सटीकता',
      'performance': 'प्रदर्शन',
      'difficulty': 'कठिनाई',
      'easy': 'आसान',
      'medium': 'मध्यम',
      'hard': 'कठिन',
      'loading': 'लोड हो रहा है...',
      'error': 'कुछ गलत हो गया',
      'try_again': 'पुनः प्रयास करें',
      'no_data': 'कोई डेटा उपलब्ध नहीं है',
      'caregiver': 'देखभालकर्ता',
      'patient': 'मरीज़',
      'caregiver_requests': 'देखभालकर्ता अनुरोध',
      'no_linked_patients': 'अभी कोई मरीज जुड़ा नहीं है।',
    },

    AppLanguage.assamese: {
      'app_name': 'স্মৃতি সাৰথি',
      'welcome': 'স্বাগতম',
      'login': 'লগইন',
      'logout': 'লগআউট',
      'register': 'পঞ্জীয়ন',
      'settings': 'ছেটিংছ',
      'language': 'ভাষা',
      'select_language': 'ভাষা বাছনি কৰক',
      'home': 'হোম',
      'games': 'খেল',
      'memory_game': 'স্মৃতি খেল',
      'attention_game': 'মনোযোগ খেল',
      'pattern_game': 'আৰ্হি খেল',
      'my_progress': 'মোৰ অগ্ৰগতি',
      'reminders': 'সোঁৱৰণী',
      'voice_assistant': 'ভইচ সহায়ক',
      'notifications': 'জাননী',
      'refresh': 'ৰিফ্ৰেছ',
      'start_game': 'খেল আৰম্ভ কৰক',
      'submit': 'দাখিল কৰক',
      'next': 'পৰৱৰ্তী',
      'cancel': 'বাতিল',
      'save': 'সংৰক্ষণ কৰক',
      'back': 'পিছলৈ',
      'score': 'স্কোৰ',
      'accuracy': 'শুদ্ধতা',
      'performance': 'কাৰ্যক্ষমতা',
      'difficulty': 'কঠিনতা',
      'easy': 'সহজ',
      'medium': 'মধ্যম',
      'hard': 'কঠিন',
      'loading': 'লোড হৈ আছে...',
      'error': 'কিবা ভুল হৈছে',
      'try_again': 'পুনৰ চেষ্টা কৰক',
      'no_data': 'কোনো তথ্য উপলব্ধ নাই',
      'caregiver': 'যত্ন লওঁতা',
      'patient': 'ৰোগী',
      'caregiver_requests': 'যত্ন লওঁতাৰ অনুৰোধ',
      'no_linked_patients': 'এতিয়ালৈ কোনো ৰোগী সংযুক্ত হোৱা নাই।',
    },

    AppLanguage.bengali: {
      'app_name': 'স্মৃতি সারথি',
      'welcome': 'স্বাগতম',
      'login': 'লগইন',
      'logout': 'লগআউট',
      'register': 'নিবন্ধন',
      'settings': 'সেটিংস',
      'language': 'ভাষা',
      'select_language': 'ভাষা নির্বাচন করুন',
      'home': 'হোম',
      'games': 'খেলা',
      'memory_game': 'স্মৃতি খেলা',
      'attention_game': 'মনোযোগ খেলা',
      'pattern_game': 'প্যাটার্ন খেলা',
      'my_progress': 'আমার অগ্রগতি',
      'reminders': 'অনুস্মারক',
      'voice_assistant': 'ভয়েস সহায়ক',
      'notifications': 'বিজ্ঞপ্তি',
      'refresh': 'রিফ্রেশ',
      'start_game': 'খেলা শুরু করুন',
      'submit': 'জমা দিন',
      'next': 'পরবর্তী',
      'cancel': 'বাতিল',
      'save': 'সংরক্ষণ করুন',
      'back': 'পিছনে',
      'score': 'স্কোর',
      'accuracy': 'নির্ভুলতা',
      'performance': 'কর্মদক্ষতা',
      'difficulty': 'কঠিনতা',
      'easy': 'সহজ',
      'medium': 'মাঝারি',
      'hard': 'কঠিন',
      'loading': 'লোড হচ্ছে...',
      'error': 'কিছু ভুল হয়েছে',
      'try_again': 'আবার চেষ্টা করুন',
      'no_data': 'কোনো তথ্য পাওয়া যায়নি',
      'caregiver': 'পরিচর্যাকারী',
      'patient': 'রোগী',
      'caregiver_requests': 'পরিচর্যাকারীর অনুরোধ',
      'no_linked_patients': 'এখনও কোনো রোগী সংযুক্ত নেই।',
    },

    AppLanguage.nepali: {
      'app_name': 'स्मृति सारथी',
      'welcome': 'स्वागत छ',
      'login': 'लगइन',
      'logout': 'लगआउट',
      'register': 'दर्ता',
      'settings': 'सेटिङहरू',
      'language': 'भाषा',
      'select_language': 'भाषा चयन गर्नुहोस्',
      'home': 'होम',
      'games': 'खेलहरू',
      'memory_game': 'स्मृति खेल',
      'attention_game': 'ध्यान खेल',
      'pattern_game': 'ढाँचा खेल',
      'my_progress': 'मेरो प्रगति',
      'reminders': 'स्मरणपत्र',
      'voice_assistant': 'आवाज सहायक',
      'notifications': 'सूचनाहरू',
      'refresh': 'रिफ्रेस',
      'start_game': 'खेल सुरु गर्नुहोस्',
      'submit': 'पेश गर्नुहोस्',
      'next': 'अर्को',
      'cancel': 'रद्द गर्नुहोस्',
      'save': 'सुरक्षित गर्नुहोस्',
      'back': 'पछाडि',
      'score': 'स्कोर',
      'accuracy': 'शुद्धता',
      'performance': 'कार्यसम्पादन',
      'difficulty': 'कठिनाइ',
      'easy': 'सजिलो',
      'medium': 'मध्यम',
      'hard': 'गाह्रो',
      'loading': 'लोड हुँदैछ...',
      'error': 'केही गलत भयो',
      'try_again': 'पुनः प्रयास गर्नुहोस्',
      'no_data': 'कुनै डाटा उपलब्ध छैन',
      'caregiver': 'हेरचाहकर्ता',
      'patient': 'बिरामी',
      'caregiver_requests': 'हेरचाहकर्ताका अनुरोधहरू',
      'no_linked_patients': 'अहिलेसम्म कुनै बिरामी जोडिएको छैन।',
    },

    AppLanguage.bodo: {
      'app_name': 'स्मृति सारथि',
      'welcome': 'फै',
      'login': 'लगइन',
      'logout': 'लगआउट',
      'register': 'रजिष्टर',
      'settings': 'सेटिं',
      'language': 'राव',
      'select_language': 'राव सायख',
      'home': 'हम',
      'games': 'खेल',
      'memory_game': 'स्मृति खेल',
      'attention_game': 'मोनजोग खेल',
      'pattern_game': 'पेटार्न खेल',
      'my_progress': 'आंनि जौगान',
      'reminders': 'सावधानि',
      'voice_assistant': 'राव साहाज',
      'notifications': 'खौरां',
      'refresh': 'फिन लाय',
      'start_game': 'खेल जागाय',
      'submit': 'दाखिल',
      'next': 'उनाव',
      'cancel': 'बातिल',
      'save': 'राख',
      'back': 'उनफिन',
      'score': 'स्कोर',
      'accuracy': 'गोरोन्थि',
      'performance': 'जौगान',
      'difficulty': 'गोजोन',
      'easy': 'सोलो',
      'medium': 'माझारि',
      'hard': 'गोजोन',
      'loading': 'लोड जाबाय...',
      'error': 'मोनसे गोरोन्थि जादों',
      'try_again': 'फिन नाजाय',
      'no_data': 'जेबो डेटा गैया',
      'caregiver': 'साहाजगिरि',
      'patient': 'बिमारि',
      'caregiver_requests': 'साहाजगिरिनि खोनास',
      'no_linked_patients': 'जेबो बिमारि जोबोद गैया।',
    },

    AppLanguage.manipuri: {
      'app_name': 'স্মৃতি সারথি',
      'welcome': 'নমস্কার',
      'login': 'লগইন',
      'logout': 'লগআউট',
      'register': 'রেজিষ্টাৰ',
      'settings': 'সেটিং',
      'language': 'লোল',
      'select_language': 'লোল শীংউ',
      'home': 'হোম',
      'games': 'গেম',
      'memory_game': 'স্মৃতি গেম',
      'attention_game': 'মাইন্ড গেম',
      'pattern_game': 'পেটাৰ্ন গেম',
      'my_progress': 'ঐগী প্রগ্রেস',
      'reminders': 'রিমাইন্ডার',
      'voice_assistant': 'ভয়েস সহায়ক',
      'notifications': 'নোটিফিকেশন',
      'refresh': 'রিফ্ৰেশ',
      'start_game': 'গেম হৌরো',
      'submit': 'সাবমিট',
      'next': 'মথং',
      'cancel': 'ক্যান্সেল',
      'save': 'সেভ',
      'back': 'মথংদা',
      'score': 'স্কোর',
      'accuracy': 'শুদ্ধতা',
      'performance': 'পারফরমেন্স',
      'difficulty': 'গোজোন',
      'easy': 'সহজ',
      'medium': 'মিডিয়ম',
      'hard': 'হার্ড',
      'loading': 'লোড তৌরি...',
      'error': 'করিগুম্বা ফত্তা জাদ্রে',
      'try_again': 'অমুক হন্না তৌরো',
      'no_data': 'ডাটা লৈতে',
      'caregiver': 'কেয়ারগিভার',
      'patient': 'পেশেন্ট',
      'caregiver_requests': 'কেয়ারগিভার রিকোয়েস্ট',
      'no_linked_patients': 'পেশেন্ট অমত্তা লিংক তৌদ্রে।',
    },

    AppLanguage.khasi: {
      'app_name': 'SmiritiSarthi',
      'welcome': 'Khublei',
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'settings': 'Settings',
      'language': 'Ktien',
      'select_language': 'Jied ia ka Ktien',
      'home': 'Home',
      'games': 'Ki Jingialehkai',
      'memory_game': 'Jingialehkai kynmaw',
      'attention_game': 'Jingialehkai pyrkhat',
      'pattern_game': 'Jingialehkai dur',
      'my_progress': 'Ka jingiaid shaphrang',
      'reminders': 'Ki jingkynmaw',
      'voice_assistant': 'Nongiarap sur',
      'notifications': 'Ki jingpyntip',
      'refresh': 'Pynshai thymmai',
      'start_game': 'Sdang ia ka jingialehkai',
      'submit': 'Phah',
      'next': 'Bud',
      'cancel': 'Pyndam',
      'save': 'Pynsah',
      'back': 'Shadien',
      'score': 'Dak',
      'accuracy': 'Ka jingbeit',
      'performance': 'Ka jingtrei',
      'difficulty': 'Ka jingeh',
      'easy': 'Suk',
      'medium': 'Pdeng',
      'hard': 'Eh',
      'loading': 'Dang load...',
      'error': 'Don ka jingbakla',
      'try_again': 'Pyrshang biang',
      'no_data': 'Ym don jingtip',
      'caregiver': 'Nongsumar',
      'patient': 'Nongpang',
      'caregiver_requests': 'Ki jingkyrpad nongsumar',
      'no_linked_patients': 'Ym pat don nongpang ba la pyniasoh.',
    },

    AppLanguage.mizo: {
      'app_name': 'SmiritiSarthi',
      'welcome': 'Chibai',
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'settings': 'Settings',
      'language': 'Ṭawng',
      'select_language': 'Ṭawng thlang rawh',
      'home': 'Home',
      'games': 'Game-te',
      'memory_game': 'Hriat reng game',
      'attention_game': 'Ngaihtuahna game',
      'pattern_game': 'Pattern game',
      'my_progress': 'Ka hma sawnna',
      'reminders': 'Hriat reng tur',
      'voice_assistant': 'Voice assistant',
      'notifications': 'Hriattirna',
      'refresh': 'Refresh',
      'start_game': 'Game tan',
      'submit': 'Submit',
      'next': 'Duh leh',
      'cancel': 'Cancel',
      'save': 'Save',
      'back': 'Kir leh',
      'score': 'Score',
      'accuracy': 'Dikna',
      'performance': 'Performance',
      'difficulty': 'Harsa dan',
      'easy': 'Awlsam',
      'medium': 'Laizawng',
      'hard': 'Harsa',
      'loading': 'Load mek...',
      'error': 'Thil diklo a awm',
      'try_again': 'Tih leh rawh',
      'no_data': 'Data a awm lo',
      'caregiver': 'Nausen sawrtu',
      'patient': 'Patient',
      'caregiver_requests': 'Caregiver request-te',
      'no_linked_patients': 'Patient link a awm lo.',
    },

    AppLanguage.kokborok: {
      'app_name': 'SmiritiSarthi',
      'welcome': 'Khulumkha',
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'settings': 'Settings',
      'language': 'Khulong',
      'select_language': 'Khulong bachai',
      'home': 'Nok',
      'games': 'Khel',
      'memory_game': 'Sriti khel',
      'attention_game': 'Monojog khel',
      'pattern_game': 'Pattern khel',
      'my_progress': 'Angni progreso',
      'reminders': 'Smarok',
      'voice_assistant': 'Voice sahayak',
      'notifications': 'Khabar',
      'refresh': 'Refresh',
      'start_game': 'Khel suru',
      'submit': 'Joma',
      'next': 'Sero',
      'cancel': 'Batol',
      'save': 'Rakh',
      'back': 'Pichla',
      'score': 'Score',
      'accuracy': 'Sothik',
      'performance': 'Kaj',
      'difficulty': 'Kothin',
      'easy': 'Sohoj',
      'medium': 'Majari',
      'hard': 'Kothin',
      'loading': 'Load khorok...',
      'error': 'Kisu bhul jago',
      'try_again': 'Abar chesta',
      'no_data': 'Kono data nai',
      'caregiver': 'Jotno grohita',
      'patient': 'Rogi',
      'caregiver_requests': 'Jotno grohitar request',
      'no_linked_patients': 'Akhon kono rogi link nai.',
    },
  };

  static String get(
    AppLanguage language,
    String key,
  ) {
    return _translations[language]?[key] ??
        _translations[AppLanguage.english]?[key] ??
        key;
  }

  static Map<String, String> forLanguage(AppLanguage language) {
    return Map.unmodifiable(
      _translations[language] ??
          _translations[AppLanguage.english]!,
    );
  }
}