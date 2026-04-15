import 'package:flutter/material.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'categories.dart';
import 'services/api_service.dart';

void main() {
  runApp(const CollectorsDiceApp());
}

class CollectorsDiceApp extends StatelessWidget {
  const CollectorsDiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Collector's Pair-A-Dice Co.",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0A0C10),
        fontFamily: 'SquadaOne',
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0090E0),
          surface: const Color(0xFF0F1218),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ─── Shared design tokens ──────────────────────────────────────────────────
class AppColors {
  static const bgBase    = Color(0xFF0A0C10);
  static const bgSurface = Color(0xFF0F1218);
  static const bgRaised  = Color(0xFF161B26);
  static const bgCard    = Color(0xFF1A2030);
  static const accent    = Color(0xFF0090E0);
  static const accentDim = Color(0x1F0090E0); // ~12% opacity
  static const accentBorder = Color(0x480090E0); // ~28% opacity
  static const textPrimary   = Color(0xFFEEF0F5);
  static const textSecondary = Color(0xA5B4C8E6); // ~65% opacity
  static const textMuted     = Color(0x668CA5C8); // ~40% opacity
  static const borderSubtle  = Color(0x0FFFFFFF); // ~6% opacity
  static const green = Color(0xFF00D46A);
  static const red   = Color(0xFFE04040);
}

// Gradient background identical to the website's ::before pseudo-element
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF07090F),
            Color(0xFF0D1220),
            Color(0xFF0A0C10),
          ],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Radial blue glow from top — mirrors the website's radial-gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -1),
                  radius: 1.0,
                  colors: [
                    Color(0x2E007ACC),
                    Color(0x00007ACC),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// Shared card/box decoration matching the website's .login-box / .modal-box
BoxDecoration webCard({double borderRadius = 16}) => BoxDecoration(
  color: const Color(0xD90F121C), // rgba(15,18,28,0.85)
  borderRadius: BorderRadius.circular(borderRadius),
  border: Border.all(color: AppColors.accentBorder, width: 1),
  boxShadow: const [
    BoxShadow(color: Color(0x990000000), blurRadius: 40, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x140090E0), blurRadius: 0, spreadRadius: 1),
  ],
);

// Shared input decoration matching the website's dark input style
InputDecoration webInput(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
  filled: true,
  fillColor: const Color(0x990A0A19), // rgba(0,10,25,0.6)
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.accentBorder, width: 1),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.accentBorder, width: 1),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
  ),
);

// Primary gradient button matching the website's .login-box button
class WebButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const WebButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(colors: [Color(0xFF004A80), Color(0xFF003D6B)])
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0072C3), Color(0xFF005FA3)],
                ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            if (onPressed != null)
              const BoxShadow(color: Color(0x4D0064C8), blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: EdgeInsets.zero,
          ),
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'SquadaOne',
                    letterSpacing: 0.07 * 17,
                  ),
                ),
        ),
      ),
    );
  }
}

// Uppercase micro-label (matches the website's input label style)
Widget webLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      fontFamily: 'SquadaOne',
    ),
  ),
);

// ─── Login Page ────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.', error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await ApiService.login(email, password);
      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CategoriesPage()),
          (_) => false,
        );
      } else {
        _showSnack(result['error'] ?? 'Invalid credentials', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        e.toString().contains('TimeoutException')
            ? 'Connection timed out. Please check your network.'
            : 'Error: $e',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AppBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with glow
                    Image.asset(
                      'assets/CPAD_Logo.png',
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),

                    // Title — matches website's .login-container h1
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

                    // Card — matches website's .login-box
                    Container(
                      decoration: webCard(),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Log In" heading
                          const Center(
                            child: Text(
                              'Log In',
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
                            enabled: !_loading,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                            decoration: webInput(''),
                          ),
                          const SizedBox(height: 16),

                          webLabel('Password'),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            enabled: !_loading,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                            decoration: webInput('').copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: _loading
                                    ? null
                                    : () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),

                          // Forgot password — right-aligned, matches website
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Color(0xB30090E0),
                                  fontSize: 12,
                                  fontFamily: 'SquadaOne',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          WebButton(
                            label: 'Log In',
                            onPressed: _loading ? null : _handleLogin,
                            loading: _loading,
                          ),
                          const SizedBox(height: 18),

                          // Sign-up link
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                    fontFamily: 'SquadaOne',
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _loading
                                      ? null
                                      : () => Navigator.push(context,
                                            MaterialPageRoute(builder: (_) => const SignUpPage())),
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 13,
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
      ),
    );
  }
}
