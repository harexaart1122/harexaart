import 'package:flutter/material.dart';

import 'package:harexaart/data/order_repository.dart';
import 'package:harexaart/data/order_store.dart';
import 'dashboard/admin_dashboard_page.dart';

class AdminWorkspacePage extends StatefulWidget {
  final String adminEmail;

  const AdminWorkspacePage({
    super.key,
    required this.adminEmail,
  });

  @override
  State<AdminWorkspacePage> createState() => _AdminWorkspacePageState();
}

class _AdminWorkspacePageState extends State<AdminWorkspacePage> {
  bool _loadingWorkspace = false;

  Future<void> _openWorkspace(
      BuildContext context, {
        required String workspaceId,
        required String workspaceName,
      }) async {
    if (_loadingWorkspace) return;

    setState(() {
      _loadingWorkspace = true;
    });

    // Simpan object navigasi sebelum async gap.
    // Ini juga menghindari warning BuildContext across async gaps.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('========================================');
      debugPrint('MEMBUKA WORKSPACE');
      debugPrint('WORKSPACE ID   : $workspaceId');
      debugPrint('WORKSPACE NAME : $workspaceName');
      debugPrint('========================================');

      final repository = OrderRepository();

      // ============================================================
      // AMBIL ORDER SESUAI WORKSPACE DARI SUPABASE
      // ============================================================

      final orders = await repository.fetchOrdersByWorkspace(
        workspaceId,
      );

      debugPrint('========================================');
      debugPrint('SUPABASE WORKSPACE LOAD BERHASIL');
      debugPrint('WORKSPACE      : $workspaceName');
      debugPrint('JUMLAH ORDER   : ${orders.length}');
      debugPrint('========================================');

      if (!mounted) return;

      // ============================================================
      // SINKRONKAN DATA KE ORDER STORE
      // ============================================================
      //
      // PENTING: order yang diambil dari Supabase SUDAH tersimpan
      // di database. Jangan gunakan addOrder() di sini karena
      // addOrder() adalah jalur INSERT order baru.
      //
      // Kita merge berdasarkan ID agar:
      // - order workspace yang baru tetap masuk ke memory;
      // - order dari workspace lain tidak ikut terhapus;
      // - tidak terjadi INSERT ulang ke Supabase;
      // - Admin, Keeper, dan Monitoring tetap memakai OrderStore
      //   yang sama sebagai source of truth.
      // ============================================================

      final store = OrderStore.instance;
      final mergedById = <String, OrderData>{
        for (final order in store.orders) order.id: order,
      };

      for (final order in orders) {
        mergedById[order.id] = order;
      }

      store.hydrateOrders(mergedById.values.toList());

      if (!mounted) return;

      setState(() {
        _loadingWorkspace = false;
      });

      // ============================================================
      // MASUK KE DASHBOARD WORKSPACE
      // ============================================================

      navigator.push(
        MaterialPageRoute(
          builder: (context) => AdminDashboardPage(
            adminEmail: widget.adminEmail,
            workspaceId: workspaceId,
            workspaceName: workspaceName,
          ),
        ),
      );
    } catch (e) {
      debugPrint('========================================');
      debugPrint('GAGAL MEMUAT WORKSPACE');
      debugPrint('WORKSPACE      : $workspaceName');
      debugPrint('ERROR          : $e');
      debugPrint('========================================');

      if (!mounted) return;

      setState(() {
        _loadingWorkspace = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat data $workspaceName. '
                'Periksa koneksi Supabase.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1050,
                    ),
                    child: Column(
                      children: [
                        // ========================================================
                        // HEADER
                        // ========================================================

                        const Text(
                          'HAREXAART',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5,
                            color: Color(0xFF1E1E22),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'ADMIN WORKSPACE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            color: Color(0xFF85858A),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          widget.adminEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9A9A9F),
                          ),
                        ),

                        const SizedBox(height: 55),

                        // ========================================================
                        // TITLE
                        // ========================================================

                        const Text(
                          'Pilih Workspace',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF242428),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Satu akun Admin dapat mengakses dua workspace '
                              'dengan data yang terpisah.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8B8B90),
                          ),
                        ),

                        const SizedBox(height: 35),

                        // ========================================================
                        // WORKSPACE CARDS
                        // ========================================================

                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 700) {
                              return Column(
                                children: [
                                  // ==================================================
                                  // HAREXAART MOBILE / TABLET
                                  // ==================================================

                                  _WorkspaceCard(
                                    icon: Icons.auto_awesome_outlined,
                                    title: 'HAREXAART',
                                    subtitle: 'HarexaArt Workspace',
                                    description:
                                    'Masuk ke sistem utama HarexaArt '
                                        'dan kelola seluruh data workspace.',
                                    buttonText: 'MASUK HAREXAART',
                                    onTap: () {
                                      _openWorkspace(
                                        context,
                                        workspaceId: 'harexaart',
                                        workspaceName: 'HarexaArt',
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 22),

                                  // ==================================================
                                  // LAVANYA ART MOBILE / TABLET
                                  // ==================================================

                                  _WorkspaceCard(
                                    icon: Icons.palette_outlined,
                                    title: 'LAVANYA ART',
                                    subtitle: 'Lavanya Art Workspace',
                                    description:
                                    'Masuk ke workspace Lavanya Art '
                                        'dengan data dan operasional terpisah.',
                                    buttonText: 'MASUK LAVANYA ART',
                                    onTap: () {
                                      _openWorkspace(
                                        context,
                                        workspaceId: 'lavanya_art',
                                        workspaceName: 'Lavanya Art',
                                      );
                                    },
                                  ),
                                ],
                              );
                            }

                            // ======================================================
                            // DESKTOP
                            // ======================================================

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ==================================================
                                // HAREXAART DESKTOP
                                // ==================================================

                                Expanded(
                                  child: _WorkspaceCard(
                                    icon: Icons.auto_awesome_outlined,
                                    title: 'HAREXAART',
                                    subtitle: 'HarexaArt Workspace',
                                    description:
                                    'Masuk ke sistem utama HarexaArt '
                                        'dan kelola seluruh data workspace.',
                                    buttonText: 'MASUK HAREXAART',
                                    onTap: () {
                                      _openWorkspace(
                                        context,
                                        workspaceId: 'harexaart',
                                        workspaceName: 'HarexaArt',
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(width: 25),

                                // ==================================================
                                // LAVANYA ART DESKTOP
                                // ==================================================

                                Expanded(
                                  child: _WorkspaceCard(
                                    icon: Icons.palette_outlined,
                                    title: 'LAVANYA ART',
                                    subtitle: 'Lavanya Art Workspace',
                                    description:
                                    'Masuk ke workspace Lavanya Art '
                                        'dengan data dan operasional terpisah.',
                                    buttonText: 'MASUK LAVANYA ART',
                                    onTap: () {
                                      _openWorkspace(
                                        context,
                                        workspaceId: 'lavanya_art',
                                        workspaceName: 'Lavanya Art',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 45),

                        // ========================================================
                        // BACK BUTTON
                        // ========================================================

                        OutlinedButton.icon(
                          onPressed: _loadingWorkspace
                              ? null
                              : () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 18,
                          ),
                          label: const Text(
                            'Kembali ke Login',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        const Text(
                          'HarexaArt System • Workspace Selection',
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
          ),

          // ==============================================================
          // LOADING OVERLAY
          // ==============================================================

          if (_loadingWorkspace)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.12),
                child: Center(
                  child: Card(
                    elevation: 8,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Memuat workspace...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF242428),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Mengambil data dari Supabase',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF85858A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// WORKSPACE CARD
// ============================================================================

class _WorkspaceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String buttonText;
  final VoidCallback onTap;

  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.buttonText,
    required this.onTap,
  });

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          0,
          isHovered ? -6 : 0,
          0,
        ),
        child: Card(
          elevation: isHovered ? 8 : 3,
          shadowColor: Colors.black.withOpacity(
            isHovered ? 0.15 : 0.08,
          ),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isHovered
                  ? const Color(0xFFD5D5DA)
                  : const Color(0xFFE7E7EB),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(35),
              child: Column(
                children: [
                  // ========================================================
                  // ICON
                  // ========================================================

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isHovered
                          ? const Color(0xFFEDEDEF)
                          : const Color(0xFFF5F5F7),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 44,
                      color: const Color(0xFF242428),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ========================================================
                  // TITLE
                  // ========================================================

                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: Color(0xFF242428),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF99999E),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF85858A),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // BUTTON
                  // ========================================================

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF242428),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(
                        widget.buttonText,
                        style: const TextStyle(
                          fontSize: 13,
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
        ),
      ),
    );
  }
}
