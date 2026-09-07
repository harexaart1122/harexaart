import 'package:flutter/material.dart';

import 'admin/admin_login_page.dart';
import 'keeper/keeper_login_page.dart';
import 'monitoring/monitoring_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 36,
              vertical: 32,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ============================================================
                // BRAND
                // ============================================================

                const Text(
                  'HAREXAART',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF202124),
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Integrated Management & Monitoring System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF92959A),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 70),

                // ============================================================
                // ACCESS AREA
                // ============================================================

                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;

                    // ========================================================
                    // DESKTOP
                    // ========================================================

                    if (width >= 1050) {
                      final double cardWidth =
                          (width - 68) / 3;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _buildAccessCard(
                              context: context,
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'ADMIN',
                              description:
                              'Kelola dan kontrol seluruh sistem HarexaArt.',
                              buttonText: 'MASUK ADMIN',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const AdminLoginPage(),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 34),

                          SizedBox(
                            width: cardWidth,
                            child: _buildAccessCard(
                              context: context,
                              icon: Icons.engineering_outlined,
                              title: 'KEEPER',
                              description:
                              'Panel operasional untuk menjalankan tugas produksi.',
                              buttonText: 'MASUK KEEPER',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const KeeperLoginPage(),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 34),

                          SizedBox(
                            width: cardWidth,
                            child: _buildAccessCard(
                              context: context,
                              icon: Icons.desktop_windows_outlined,
                              title: 'MONITORING',
                              description:
                              'Layar informasi dan aktivitas realtime.',
                              buttonText: 'BUKA MONITORING',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const MonitoringPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    // ========================================================
                    // TABLET
                    // ========================================================

                    if (width >= 650) {
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildAccessCard(
                                  context: context,
                                  icon: Icons
                                      .admin_panel_settings_outlined,
                                  title: 'ADMIN',
                                  description:
                                  'Kelola dan kontrol seluruh sistem HarexaArt.',
                                  buttonText: 'MASUK ADMIN',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const AdminLoginPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildAccessCard(
                                  context: context,
                                  icon: Icons.engineering_outlined,
                                  title: 'KEEPER',
                                  description:
                                  'Panel operasional untuk menjalankan tugas produksi.',
                                  buttonText: 'MASUK KEEPER',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const KeeperLoginPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: width * 0.48,
                            child: _buildAccessCard(
                              context: context,
                              icon: Icons.desktop_windows_outlined,
                              title: 'MONITORING',
                              description:
                              'Layar informasi dan aktivitas realtime.',
                              buttonText: 'BUKA MONITORING',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const MonitoringPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    // ========================================================
                    // MOBILE
                    // ========================================================

                    return Column(
                      children: [
                        _buildAccessCard(
                          context: context,
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'ADMIN',
                          description:
                          'Kelola dan kontrol seluruh sistem HarexaArt.',
                          buttonText: 'MASUK ADMIN',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const AdminLoginPage(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        _buildAccessCard(
                          context: context,
                          icon: Icons.engineering_outlined,
                          title: 'KEEPER',
                          description:
                          'Panel operasional untuk menjalankan tugas produksi.',
                          buttonText: 'MASUK KEEPER',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const KeeperLoginPage(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        _buildAccessCard(
                          context: context,
                          icon: Icons.desktop_windows_outlined,
                          title: 'MONITORING',
                          description:
                          'Layar informasi dan aktivitas realtime.',
                          buttonText: 'BUKA MONITORING',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const MonitoringPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 70),

                // ============================================================
                // FOOTER
                // ============================================================

                const Text(
                  'HarexaArt System • Connected Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF999CA1),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Version 1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB5B7BB),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACCESS CARD
  // ============================================================

  Widget _buildAccessCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        32,
        38,
        32,
        32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE0E1E4),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ================================================================
          // ICON
          // ================================================================

          Container(
            width: 108,
            height: 108,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F5F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF27282C),
              size: 50,
            ),
          ),

          const SizedBox(height: 30),

          // ================================================================
          // TITLE
          // ================================================================

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF292A2E),
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 20),

          // ================================================================
          // DESCRIPTION
          // ================================================================

          SizedBox(
            height: 66,
            child: Center(
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8B8E94),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ================================================================
          // BUTTON
          // ================================================================

          SizedBox(
            width: double.infinity,
            height: 62,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF292A2E),
                backgroundColor: Colors.white,
                side: const BorderSide(
                  color: Color(0xFFD5D6DA),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
}

