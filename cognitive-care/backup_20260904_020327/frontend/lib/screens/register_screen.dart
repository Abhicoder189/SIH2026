
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedRole = 'elderly';
  String _selectedLanguage = 'English';

  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _languages = [
    'English',
    'Hindi',
    'Assamese',
    'Bengali',
    'Manipuri',
    'Mizo',
    'Khasi',
    'Garo',
    'Tripuri',
    'Nagamese',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        age: int.parse(_ageController.text.trim()),
        language: _selectedLanguage,
      );

      await AuthService.saveLogin(
        token: result['access_token'],
        userId: result['user_id'],
        role: result['role'],
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            userId: result['user_id'],
            role: result['role'],
            token: result['access_token'],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 70,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Create Your Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Enter your details to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // NAME
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Full Name',
                        icon: Icons.person,
                        hint: 'Enter your full name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Enter a valid name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // EMAIL
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Email',
                        icon: Icons.email,
                        hint: 'Enter your email',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your email';
                        }

                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // PASSWORD
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Password',
                        icon: Icons.lock,
                        hint: 'Minimum 8 characters',
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Password must contain at least 8 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // AGE
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Age',
                        icon: Icons.cake,
                        hint: 'Enter age',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your age';
                        }

                        final age = int.tryParse(value.trim());

                        if (age == null) {
                          return 'Age must be a number';
                        }

                        if (age < 1 || age > 120) {
                          return 'Enter an age between 1 and 120';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // LANGUAGE
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLanguage,
                      decoration: _inputDecoration(
                        label: 'Preferred Language',
                        icon: Icons.language,
                      ),
                      items: _languages.map((language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(language),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // ROLE
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: _inputDecoration(
                        label: 'Account Type',
                        icon: Icons.badge,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'elderly',
                          child: Text('Elderly User'),
                        ),
                        DropdownMenuItem(
                          value: 'caregiver',
                          child: Text('Caregiver'),
                        ),
                        DropdownMenuItem(
                          value: 'health_worker',
                          child: Text('Health Worker'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 28),

                    // REGISTER BUTTON
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(),
                              )
                            : const Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      child: const Text(
                        'Already have an account? Login',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
