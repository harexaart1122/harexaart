
import 'package:flutter/material.dart';

import '../../../data/order_store.dart';
import 'payment_page.dart';

/// ============================================================================
/// HAREXAART - FINANCE PAGE
/// ============================================================================
///
/// Halaman utama modul Keuangan.
///
/// Alur data:
///
/// ADMIN INPUT ORDER
///        ↓
/// ORDER STORE
///        ↓
/// KEEPER
///        ↓
/// FINANCE
///
/// Workspace:
/// - HarexaArt      -> harexaart
/// - Lavanya Art    -> lavanya_art
///
/// Data kedua workspace TIDAK boleh dicampur.
/// ============================================================================

class FinancePage extends StatefulWidget {
  final String adminEmail;
  final String workspaceId;
  final String workspaceName;

  const FinancePage({
    super.key,
    required this.adminEmail,
    required this.workspaceId,
    required this.workspaceName,
  });

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  int selectedMenu = 0;

  /// ==========================================================================
  /// INIT
  /// ==========================================================================

  @override
  void initState() {
    super.initState();

    /// Finance ikut mendengarkan perubahan OrderStore.
    ///
    /// Contoh:
    /// Keeper menyelesaikan order
    ///        ↓
    /// OrderStore berubah
    ///        ↓
    /// Finance otomatis refresh
    OrderStore.instance.addListener(_handleOrderStoreChanged);
  }

  /// ==========================================================================
  /// DISPOSE
  /// ==========================================================================

  @override
  void dispose() {
    OrderStore.instance.removeListener(_handleOrderStoreChanged);
    super.dispose();
  }

  /// ==========================================================================
  /// ORDER STORE CHANGE
  /// ==========================================================================

  void _handleOrderStoreChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  /// ==========================================================================
  /// WORKSPACE
  /// ==========================================================================

  bool get isHarexaArt {
    return widget.workspaceId == 'harexaart';
  }

  String get workspaceDisplayName {
    if (widget.workspaceName.trim().isNotEmpty) {
      return widget.workspaceName;
    }

    if (isHarexaArt) {
      return 'HarexaArt';
    }

    return 'Lavanya Art';
  }

  /// ==========================================================================
  /// DATA KEUANGAN WORKSPACE
  /// ==========================================================================

  int get _unpaidTotal {
    return OrderStore.instance.getUnpaidTotalByWorkspace(
      widget.workspaceId,
    );
  }

  int get _paidTotal {
    return OrderStore.instance.getPaidTotalByWorkspace(
      widget.workspaceId,
    );
  }

  int get _transactionCount {
    return OrderStore.instance.getOrderCountByWorkspace(
      widget.workspaceId,
    );
  }

  int get _unpaidCount {
    return OrderStore.instance.getUnpaidCountByWorkspace(
      widget.workspaceId,
    );
  }

  int get _paidCount {
    return OrderStore.instance.getPaidCountByWorkspace(
      widget.workspaceId,
    );
  }

  /// ==========================================================================
  /// FORMAT RUPIAH
  /// ==========================================================================

  String _formatRupiah(int value) {
    final String digits = value.toString();

    if (digits.isEmpty) {
      return 'Rp 0';
    }

    final StringBuffer result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final int positionFromEnd = digits.length - i;

      result.write(digits[i]);

      if (positionFromEnd > 1 &&
          positionFromEnd % 3 == 1) {
        result.write('.');
      }
    }

    return 'Rp ${result.toString()}';
  }

  /// ==========================================================================
  /// BUILD
  /// ==========================================================================

  /// ========================================================================
  /// BUILD - RESPONSIVE
  /// ========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 820;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          drawer: mobile ? _buildMobileDrawer() : null,
          appBar: mobile
              ? AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF202124), fontSize: 17, fontWeight: FontWeight.w700)),
                Text(workspaceDisplayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF92959A), fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 125),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(10)),
                    child: Text(workspaceDisplayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A4B50), fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          )
              : null,
          body: SafeArea(
            top: !mobile,
            child: mobile
                ? _buildContent()
                : Row(
              children: [
                _buildSidebar(),
                Expanded(child: Column(children: [_buildTopBar(), Expanded(child: _buildContent())])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Column(
                children: [
                  const Text('HAREXAART', style: TextStyle(color: Color(0xFF202124), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3)),
                  const SizedBox(height: 5),
                  const Text('FINANCE', style: TextStyle(color: Color(0xFF92959A), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(13)),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF4A4B50), size: 18),
                      const SizedBox(width: 9),
                      Expanded(child: Text(workspaceDisplayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF28292D), fontSize: 12, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildMenuItem(icon: Icons.dashboard_outlined, title: 'Ringkasan Keuangan', index: 0),
            _buildMenuItem(icon: Icons.payments_outlined, title: 'Pembayaran', index: 1),
            _buildMenuItem(icon: Icons.receipt_long_outlined, title: 'Riwayat Pembayaran', index: 2),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.person_outline, color: Color(0xFF303136), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.adminEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF303136), fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// ==========================================================================
  /// SIDEBAR
  /// ==========================================================================

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE5E6E9),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),

          // --------------------------------------------------------------------
          // BRAND
          // --------------------------------------------------------------------

          const Text(
            'HAREXAART',
            style: TextStyle(
              color: Color(0xFF202124),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'FINANCE',
            style: TextStyle(
              color: Color(0xFF92959A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 34),

          // --------------------------------------------------------------------
          // WORKSPACE
          // --------------------------------------------------------------------

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7E7EA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isHarexaArt
                          ? Icons.auto_awesome_outlined
                          : Icons.palette_outlined,
                      color: const Color(0xFF292A2E),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WORKSPACE',
                          style: TextStyle(
                            color: Color(0xFF999BA0),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          workspaceDisplayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF28292D),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // --------------------------------------------------------------------
          // MENU
          // --------------------------------------------------------------------

          _buildMenuItem(
            icon: Icons.dashboard_outlined,
            title: 'Ringkasan Keuangan',
            index: 0,
          ),

          _buildMenuItem(
            icon: Icons.payments_outlined,
            title: 'Pembayaran',
            index: 1,
          ),

          _buildMenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'Riwayat Pembayaran',
            index: 2,
          ),

          const Spacer(),

          // --------------------------------------------------------------------
          // ADMIN INFO
          // --------------------------------------------------------------------

          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E5E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF303136),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Color(0xFF9A9BA0),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.adminEmail,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF303136),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ==========================================================================
  /// SIDEBAR MENU ITEM
  /// ==========================================================================

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool selected = selectedMenu == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            /// --------------------------------------------------------------
            /// PEMBAYARAN
            /// --------------------------------------------------------------
            ///
            /// PaymentPage dibuka sebagai halaman khusus.
            ///
            /// Workspace dikirim langsung sehingga:
            ///
            /// HarexaArt → hanya HarexaArt
            /// Lavanya Art → hanya Lavanya Art
            ///
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentPage(
                    adminEmail: widget.adminEmail,
                    workspaceId: widget.workspaceId,
                    workspaceName: workspaceDisplayName,
                  ),
                ),
              );

              return;
            }

            setState(() {
              selectedMenu = index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFEAE9EE)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? const Color(0xFF202124)
                      : const Color(0xFF85878C),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF202124)
                          : const Color(0xFF74767B),
                      fontSize: 13,
                      fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ==========================================================================
  /// TOP BAR
  /// ==========================================================================

  /// ========================================================================
  /// TOP BAR - DESKTOP RESPONSIVE
  /// ========================================================================

  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 1050;
        return Container(
          height: compact ? 70 : 76,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5E6E9)))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: const Color(0xFF202124), fontSize: compact ? 17 : 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(workspaceDisplayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF92959A), fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (!compact) ...[
                Container(
                  constraints: const BoxConstraints(maxWidth: 210),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(11)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 17, color: Color(0xFF4A4B50)),
                    const SizedBox(width: 8),
                    Flexible(child: Text(workspaceDisplayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A4B50), fontSize: 11, fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(width: 14),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Kembali'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF34353A), side: const BorderSide(color: Color(0xFFD9DADD)), padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 15, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }


  /// ==========================================================================
  /// PAGE TITLE
  /// ==========================================================================

  String get _pageTitle {
    switch (selectedMenu) {
      case 1:
        return 'Pembayaran';

      case 2:
        return 'Riwayat Pembayaran';

      case 0:
      default:
        return 'Ringkasan Keuangan';
    }
  }

  /// ==========================================================================
  /// CONTENT
  /// ==========================================================================

  /// ========================================================================
  /// CONTENT - RESPONSIVE CONTAINER
  /// ========================================================================

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 28, vertical: mobile ? 16 : 28),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: _buildSelectedContent(),
            ),
          ),
        );
      },
    );
  }


  /// ==========================================================================
  /// SELECTED CONTENT
  /// ==========================================================================

  Widget _buildSelectedContent() {
    switch (selectedMenu) {
      case 2:
        return _buildHistoryPlaceholder();

      case 0:
      default:
        return _buildSummary();
    }
  }

  /// ==========================================================================
  /// SUMMARY
  /// ==========================================================================

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeHeader(),
        const SizedBox(height: 28),

        // --------------------------------------------------------------------
        // SUMMARY CARDS
        // --------------------------------------------------------------------

        LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 900;

            final cards = [
              _buildSummaryCard(
                icon: Icons.pending_actions_outlined,
                title: 'Menunggu Pembayaran',
                value: _formatRupiah(_unpaidTotal),
                description:
                '$_unpaidCount order SELESAI dan belum dibayar',
              ),
              _buildSummaryCard(
                icon: Icons.payments_outlined,
                title: 'Sudah Dibayar',
                value: _formatRupiah(_paidTotal),
                description:
                '$_paidCount pembayaran telah difinalisasi',
              ),
              _buildSummaryCard(
                icon: Icons.receipt_long_outlined,
                title: 'Total Transaksi',
                value: _transactionCount.toString(),
                description:
                'Jumlah transaksi pada workspace',
              ),
            ];

            if (compact) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 14),
                  cards[1],
                  const SizedBox(height: 14),
                  cards[2],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 16),
                Expanded(child: cards[1]),
                const SizedBox(width: 16),
                Expanded(child: cards[2]),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // --------------------------------------------------------------------
        // INFORMATION PANEL
        // --------------------------------------------------------------------

        _buildInformationPanel(),
      ],
    );
  }

  /// ==========================================================================
  /// WELCOME HEADER
  /// ==========================================================================

  Widget _buildWelcomeHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 520;
        final icon = Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFF0F0F2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.account_balance_wallet_outlined, size: 28, color: Color(0xFF2A2B2F)));
        final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pusat Keuangan', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF25262A), fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Monitoring keuangan untuk $workspaceDisplayName.', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8E93), fontSize: 12, height: 1.5)),
        ]);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(mobile ? 18 : 26),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE4E5E8))),
          child: mobile ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [icon, const SizedBox(height: 14), text]) : Row(children: [icon, const SizedBox(width: 18), Expanded(child: text)]),
        );
      },
    );
  }


  /// ==========================================================================
  /// SUMMARY CARD
  /// ==========================================================================

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E5E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF34353A),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.more_horiz,
                color: Color(0xFFB0B1B5),
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF77797E),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF242529),
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFA0A1A5),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// ==========================================================================
  /// INFORMATION PANEL
  /// ==========================================================================

  Widget _buildInformationPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E5E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 19,
                color: Color(0xFF55565B),
              ),
              SizedBox(width: 9),
              Text(
                'Alur Data Keuangan',
                style: TextStyle(
                  color: Color(0xFF2B2C30),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildFlowItem(
            number: '01',
            title: 'Input Admin',
            description:
            'Harga final, foto produk, ID order, ukuran, frame, '
                'dan tanggal input berasal dari Input Order.',
          ),

          _buildFlowDivider(),

          _buildFlowItem(
            number: '02',
            title: 'Keeper',
            description:
            'Finance menunggu order benar-benar berstatus SELESAI '
                'dan menggunakan timestamp penyelesaian Keeper.',
          ),

          _buildFlowDivider(),

          _buildFlowItem(
            number: '03',
            title: 'Pembayaran Admin',
            description:
            'Admin dapat memfinalisasi pembayaran menggunakan nominal '
                'asli dari order tanpa mengetik ulang harga.',
          ),

          _buildFlowDivider(),

          _buildFlowItem(
            number: '04',
            title: 'PDF & Audit',
            description:
            'Setelah pembayaran difinalisasi, sistem menyimpan '
                'tanggal pembayaran dan menghasilkan laporan PDF.',
          ),
        ],
      ),
    );
  }

  /// ==========================================================================
  /// FLOW ITEM
  /// ==========================================================================

  Widget _buildFlowItem({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F2),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFF38393E),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF323338),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF8B8D92),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ==========================================================================
  /// FLOW DIVIDER
  /// ==========================================================================

  Widget _buildFlowDivider() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 18,
        top: 12,
        bottom: 12,
      ),
      child: Container(
        width: 1,
        height: 15,
        color: const Color(0xFFE0E1E4),
      ),
    );
  }

  /// ==========================================================================
  /// HISTORY PLACEHOLDER
  /// ==========================================================================

  Widget _buildHistoryPlaceholder() {
    return _buildModulePlaceholder(
      icon: Icons.receipt_long_outlined,
      title: 'Riwayat Pembayaran',
      description:
      'Riwayat pembayaran akan menampilkan transaksi yang sudah '
          'difinalisasi oleh Admin beserta timestamp pembayaran.',
    );
  }

  /// ==========================================================================
  /// MODULE PLACEHOLDER
  /// ==========================================================================

  Widget _buildModulePlaceholder({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
        ),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.all(38),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE4E5E8),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: const Color(0xFF34353A),
                ),
              ),

              const SizedBox(height: 22),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF292A2E),
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF898B90),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'MODUL SEDANG DISIAPKAN',
                  style: TextStyle(
                    color: Color(0xFF77787D),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
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
