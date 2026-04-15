import 'package:flutter/material.dart';
import 'login.dart' show AppBackground, AppColors, webCard, webInput, webLabel, WebButton;
import 'services/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _handleSendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email address.', error: true);
      return;
    }

    try {
      final result = await ApiService.resetPassword(email);
      if (!mounted) return;

      if (result['success'] == true) {
        _showSnack('If that email exists, a reset link has been sent.', error: false);
        Navigator.pop(context);
      } else {
        _showSnack(result['error'] ?? 'Failed to send reset email', error: true);
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
                            'Forgot Password',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'SquadaOne',
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            "Enter your email and we'll send you a reset link.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontFamily: 'SquadaOne',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        webLabel('Email'),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          decoration: webInput(''),
                        ),
                        const SizedBox(height: 22),

                        WebButton(label: 'Send Reset Email', onPressed: _handleSendReset),
                        const SizedBox(height: 18),

                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Return to sign in',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontFamily: 'SquadaOne',
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.accent,
                              ),
                            ),
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
