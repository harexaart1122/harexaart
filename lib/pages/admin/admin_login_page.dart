import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_workspace_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Email dan password wajib diisi.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.session == null) {
        setState(() {
          isLoading = false;
        });

        _showMessage(
          'Login gagal. Session Supabase tidak terbentuk.',
        );
        return;
      }

      setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminWorkspacePage(
            adminEmail: email,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint('========================================');
      debugPrint('SUPABASE AUTH ERROR MESSAGE: ${e.message}');
      debugPrint('SUPABASE AUTH ERROR STATUS: ${e.statusCode}');
      debugPrint('========================================');

      _showMessage(
        'AUTH ERROR: ${e.message}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Terjadi kesalahan saat login. Silakan coba lagi.',
      );

      debugPrint('SUPABASE ADMIN LOGIN ERROR: $e');
    }
  }

  String _authErrorMessage(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials')) {
      return 'Email atau password salah.';
    }

    if (normalized.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi.';
    }

    if (normalized.contains('too many requests')) {
      return 'Terlalu banyak percobaan login. Coba lagi beberapa saat.';
    }

    if (normalized.contains('user not found')) {
      return 'Akun tidak ditemukan.';
    }

    return 'Login gagal. Periksa email dan password.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ========================================================
                  // ADMIN ICON
                  // ========================================================

                  Container(
                    width: 86,
                    height: 86,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEDEDEF),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 46,
                      color: Color(0xFF242428),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ========================================================
                  // BRAND
                  // ========================================================

                  const Text(
                    'HAREXAART',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                      color: Color(0xFF1E1E22),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'ADMIN ACCESS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Color(0xFF85858A),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // ========================================================
                  // LOGIN CARD
                  // ========================================================

                  Card(
                    elevation: 3,
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(
                        color: Color(0xFFE6E6EA),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Selamat Datang',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF242428),
                            ),
                          ),

                          const SizedBox(height: 9),

                          const Text(
                            'Masuk untuk mengakses sistem Admin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF8B8B90),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ==================================================
                          // EMAIL
                          // ==================================================

                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: !isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Masukkan email admin',
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDADADF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF242428),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ==================================================
                          // PASSWORD
                          // ==================================================

                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !isLoading,
                            onSubmitted: (_) {
                              if (!isLoading) {
                                _login();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Masukkan password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () {
                                  setState(() {
                                    obscurePassword =
                                    !obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDADADF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF242428),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ==================================================
                          // LOGIN BUTTON
                          // ==================================================

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF242428),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFFBDBDC2),
                                disabledForegroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                                  : const Text(
                                'LOGIN ADMIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          // ==================================================
                          // BACK BUTTON
                          // ==================================================

                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              '← Kembali',
                              style: TextStyle(
                                color: Color(0xFF66666B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'HarexaArt System • Admin Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A9A9F),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
