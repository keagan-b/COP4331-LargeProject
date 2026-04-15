import 'package:flutter/material.dart';
import 'login.dart' show AppBackground, AppColors, webCard, webInput, webLabel, WebButton;
import 'services/api_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all fields.', error: true);
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match.', error: true);
      return;
    }

    try {
      final result = await ApiService.signup(email, password);
      if (!mounted) return;

      if (result['success'] == true) {
        _showSnack('Account created! Please verify your email.', error: false);
        Navigator.pop(context);
      } else {
        _showSnack(result['error'] ?? 'Sign up failed', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.red : AppColors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/CPAD_Logo.png', height: 80, fit: BoxFit.contain),
                  const SizedBox(height: 10),
                  const Text(
                    "Collector's Pair-A-Dice",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'SquadaOne',
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    decoration: webCard(),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'SquadaOne',
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        webLabel('Email'),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          decoration: webInput(''),
                        ),
                        const SizedBox(height: 16),

                        webLabel('Password'),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          decoration: webInput('').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textMuted, size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        webLabel('Confirm Password'),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          decoration: webInput('').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textMuted, size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        WebButton(label: 'Sign Up', onPressed: _handleSignUp),
                        const SizedBox(height: 18),

                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13, fontFamily: 'SquadaOne',
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: AppColors.accent, fontSize: 13,
                                    fontFamily: 'SquadaOne',
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
