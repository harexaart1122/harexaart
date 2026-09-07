import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard/keeper_dashboard_page.dart';

class KeeperLoginPage extends StatefulWidget {
  const KeeperLoginPage({super.key});

  @override
  State<KeeperLoginPage> createState() => _KeeperLoginPageState();
}

class _KeeperLoginPageState extends State<KeeperLoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Username dan password wajib diisi.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // ==========================================================
      // 1. CARI EMAIL INTERNAL BERDASARKAN USERNAME KEEPER
      // ==========================================================

      final result = await Supabase.instance.client.rpc(
        'get_keeper_login_email',
        params: <String, dynamic>{
          'p_username': username,
        },
      );

      final internalEmail = result?.toString().trim() ?? '';

      if (internalEmail.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        _showMessage(
          'Username Keeper tidak ditemukan atau tidak aktif.',
        );
        return;
      }

      // ==========================================================
      // 2. LOGIN SUPABASE AUTH MENGGUNAKAN EMAIL INTERNAL
      // ==========================================================

      final response =
      await Supabase.instance.client.auth.signInWithPassword(
        email: internalEmail,
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

      // ==========================================================
      // 3. LOGIN BERHASIL → KEEPER DASHBOARD
      // ==========================================================

      setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const KeeperDashboardPage(),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        _authErrorMessage(e.message),
      );

      debugPrint(
        'SUPABASE KEEPER AUTH ERROR: ${e.message}',
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Sistem login Keeper belum dapat mengakses data akun.',
      );

      debugPrint(
        'SUPABASE KEEPER RPC ERROR: ${e.message}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Terjadi kesalahan saat login. Silakan coba lagi.',
      );

      debugPrint(
        'SUPABASE KEEPER LOGIN ERROR: $e',
      );
    }
  }

  String _authErrorMessage(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials')) {
      return 'Username atau password salah.';
    }

    if (normalized.contains('email not confirmed')) {
      return 'Akun Keeper belum dikonfirmasi.';
    }

    if (normalized.contains('too many requests')) {
      return 'Terlalu banyak percobaan login. Coba lagi beberapa saat.';
    }

    if (normalized.contains('user not found')) {
      return 'Akun Keeper tidak ditemukan.';
    }

    return 'Username atau password salah.';
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
                  // ==========================================================
                  // KEEPER ICON
                  // ==========================================================

                  Container(
                    width: 86,
                    height: 86,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEDEDEF),
                    ),
                    child: const Icon(
                      Icons.engineering_outlined,
                      size: 46,
                      color: Color(0xFF242428),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ==========================================================
                  // BRAND
                  // ==========================================================

                  const Text(
                    'HAREXAART',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                      color: Color(0xFF1E1E22),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'KEEPER ACCESS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Color(0xFF85858A),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // ==========================================================
                  // LOGIN CARD
                  // ==========================================================

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
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Login Keeper',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF202124),
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Masuk untuk mengakses panel operasional.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF85858A),
                            ),
                          ),

                          const SizedBox(height: 26),

                          // ==================================================
                          // USERNAME
                          // ==================================================

                          TextField(
                            controller: usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            enabled: !isLoading,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'Masukkan username Keeper',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F8FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E2E6),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E2E6),
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
                              hintText: 'Masukkan password Keeper',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
                                onPressed: isLoading
                                    ? null
                                    : () {
                                  setState(() {
                                    obscurePassword =
                                    !obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F8FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E2E6),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E2E6),
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

                          const SizedBox(height: 26),

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
                                const Color(0xFFB9B9BD),
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
                                'MASUK KEEPER',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================================
                  // SECURITY INFO
                  // ==========================================================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: Color(0xFF999CA1),
                      ),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Akses Keeper dilindungi oleh Supabase Auth',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999CA1),
                          ),
                        ),
                      ),
                    ],
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