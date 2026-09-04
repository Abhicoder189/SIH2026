import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter email and password.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ----------------------------------------------------------
      // 1. LOGIN
      // ----------------------------------------------------------

      final result = await ApiService.login(
        email,
        password,
      );

      final token = result['access_token']?.toString();
      final userId = result['user_id']?.toString();
      final role = result['role']?.toString();

      if (token == null ||
          token.isEmpty ||
          userId == null ||
          userId.isEmpty ||
          role == null ||
          role.isEmpty) {
        throw Exception(
          'Login response did not contain valid authentication data.',
        );
      }

      // ----------------------------------------------------------
      // 2. SAVE TOKEN
      // ----------------------------------------------------------

      await AuthService.saveLogin(
        token: token,
        userId: userId,
        role: role,
      );

      // ----------------------------------------------------------
      // 3. VERIFY TOKEN
      // ----------------------------------------------------------
      //
      // This makes sure the exact token stored by Flutter
      // is accepted by the backend.
      //

      final profile = await ApiService.getCurrentUser(token);

      debugPrint('LOGIN SUCCESS');
      debugPrint('User ID: $userId');
      debugPrint('Role: $role');
      debugPrint('Authenticated user: $profile');

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------
      // 4. OPEN HOME SCREEN
      // ----------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            userId: userId,
            role: role,
            token: token,
          ),
        ),
      );
    } catch (error) {
      debugPrint('LOGIN ERROR: $error');

      // Remove potentially invalid/stale credentials.
      await AuthService.logout();

      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              const Icon(
                Icons.lock,
                size: 90,
              ),

              const SizedBox(height: 25),

              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 35),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontSize: 22,
                ),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    fontSize: 22,
                  ),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.email,
                    size: 30,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(
                  fontSize: 22,
                ),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    fontSize: 22,
                  ),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.lock,
                    size: 30,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 20),

              SizedBox(
                height: 70,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const SizedBox(
                          height: 30,
                          width: 30,
                          child: CircularProgressIndicator(),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text(
                  'Create a new account',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}