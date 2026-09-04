import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() => runApp(const SmiritiSarthiApp());

class SmiritiSarthiApp extends StatelessWidget {
  const SmiritiSarthiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SmiritiSarthi',
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

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  Future<List<String?>> _session() async => [
        await AuthService.getToken(),
        await AuthService.getUserId(),
        await AuthService.getRole(),
      ];

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String?>>(
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