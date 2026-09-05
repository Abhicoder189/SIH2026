import 'package:flutter/material.dart';

import 'l10n/language_service.dart';
import 'l10n/translations.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() => runApp(const SmiritiSarthiApp());

class SmiritiSarthiApp extends StatefulWidget {
  const SmiritiSarthiApp({super.key});

  @override
  State<SmiritiSarthiApp> createState() => _SmiritiSarthiAppState();
}

class _SmiritiSarthiAppState extends State<SmiritiSarthiApp> {
  AppLanguage _language = AppLanguage.english;
  bool _languageLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await LanguageService.getLanguage();

    if (!mounted) return;

    setState(() {
      _language = language;
      _languageLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_languageLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppTranslations.get(_language, 'app_name'),

      locale: _language.locale,

      supportedLocales: AppLanguage.values
          .map((language) => language.locale)
          .toList(),

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),

      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  Future<List<String?>> _session() async {
    return [
      await AuthService.getToken(),
      await AuthService.getUserId(),
      await AuthService.getRole(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: _session(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final values = snapshot.data!;

        if (values[0] == null ||
            values[1] == null ||
            values[2] == null) {
          return const LoginScreen();
        }

        return HomeScreen(
          token: values[0]!,
          userId: values[1]!,
          role: values[2]!,
        );
      },
    );
  }
}