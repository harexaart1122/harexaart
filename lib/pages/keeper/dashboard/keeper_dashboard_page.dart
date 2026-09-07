import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import '../../../data/order_repository.dart';
import '../../../data/order_store.dart';

bool _keeperIsPdfBytes(Uint8List bytes) {
  if (bytes.length < 4) return false;
  final h = String.fromCharCodes(bytes.take(8));
  return h.startsWith('%PDF-');
}

class KeeperDashboardPage extends StatefulWidget {
  const KeeperDashboardPage({
    super.key,
  });

  @override
  State<KeeperDashboardPage> createState() => _KeeperDashboardPageState();
}

class _KeeperDashboardPageState extends State<KeeperDashboardPage> {
  int selectedMenu = 0;
  bool sidebarExpanded = true;
  String? activeWorkspaceId;
  int workspaceMenu = 0;

  final List<_KeeperOrder> orders = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    OrderStore.instance.removeListener(_syncOrdersFromStore);
    super.dispose();
  }

  void _syncOrdersFromStore() {
    if (!mounted) return;

    final storeOrders = OrderStore.instance.orders;

    final synced = storeOrders.map((storeOrder) {
      final stage = storeOrder.keeperStage;

      return _KeeperOrder(
        id: storeOrder.id,
        workspaceName: storeOrder.workspaceName,
        workspaceId: storeOrder.workspaceId,
        ukuran: storeOrder.ukuran,
        frame: storeOrder.frame,
        deadlineDays: storeOrder.deadlineDays,
        receivedAt: storeOrder.createdAt,
        productName: storeOrder.productName,
        productImageFileName: storeOrder.productImageFileName,
        catatan: storeOrder.catatan,
        price: storeOrder.price,
        productImage: storeOrder.productImage,
        productImageUrl: storeOrder.productImageUrl,
        status: _stageLabel(stage),
        keeperStage: stage,
        paymentStatus: storeOrder.paymentStatus,
        completedAt: storeOrder.completedAt,
        paidAt: storeOrder.paidAt,
      )
        ..shippingCourier = storeOrder.shippingCourier
        ..shippingReceiptImage = storeOrder.shippingReceiptImage
        ..shippingReceiptFileName = storeOrder.shippingReceiptFileName
        ..shippingReceiptUrl = storeOrder.shippingReceiptUrl
        ..shippingDate = storeOrder.shippingDate;
    }).toList();

    setState(() {
      orders
        ..clear()
        ..addAll(synced);
    });
  }

  String _stageLabel(KeeperStage stage) {
    switch (stage) {
      case KeeperStage.orderanMasuk:
        return 'ORDERAN MASUK';
      case KeeperStage.sedangDikerjakan:
        return 'SEDANG DIKERJAKAN';
      case KeeperStage.inputResi:
        return 'SIAP DIKIRIM';
      case KeeperStage.selesaiDikerjakan:
        return 'SELESAI';
    }
  }

  Future<void> _loadOrdersFromSupabase() async {
    try {
      final repository = OrderRepository();
      final fetchedOrders = await repository.fetchOrders();

      if (!mounted) return;

      // Order yang berasal dari Supabase hanya dimuat ke memory.
      // Jangan gunakan addOrder() di sini karena addOrder() melakukan INSERT.
      OrderStore.instance.hydrateOrders(fetchedOrders);

      debugPrint('========================================');
      debugPrint('KEEPER SUPABASE LOAD BERHASIL');
      debugPrint('JUMLAH ORDER : ${fetchedOrders.length}');
      debugPrint('========================================');
    } catch (e) {
      debugPrint('========================================');
      debugPrint('KEEPER SUPABASE LOAD GAGAL');
      debugPrint('ERROR: $e');
      debugPrint('========================================');
    }
  }

  @override
  void initState() {
    super.initState();

    // Data produksi tidak dibuat di Keeper. Semua order berasal dari OrderStore.
    OrderStore.instance.addListener(_syncOrdersFromStore);
    _syncOrdersFromStore();

    // Saat Keeper dibuka langsung dari halaman akses, OrderStore bisa masih kosong.
    // Muat data terbaru dari Supabase tanpa mengubah UI atau workflow Keeper.
    unawaited(_loadOrdersFromSupabase());
  }

  // ============================================================
  // NAVIGASI BACK / KEMBALI
  // ============================================================

  void _handleBack() {
    if (activeWorkspaceId != null && workspaceMenu != 0) {
      setState(() => workspaceMenu = 0);
      return;
    }

    if (activeWorkspaceId != null) {
      setState(() {
        activeWorkspaceId = null;
        selectedMenu = 0;
        workspaceMenu = 0;
      });
      return;
    }

    if (selectedMenu != 0) {
      setState(() => selectedMenu = 0);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _openWorkspace(String workspaceId) {
    setState(() {
      activeWorkspaceId = workspaceId;
      workspaceMenu = 0;
      _financeSection = 'overview';
    });
  }

  String get _activeWorkspaceName => activeWorkspaceId == 'lavanya_art'
      ? 'Lavanya Art'
      : 'HarexaArt';

  List<_KeeperOrder> get _visibleOrders {
    final source = activeWorkspaceId == null
        ? orders
        : orders.where((o) => o.workspaceId == activeWorkspaceId).toList();
    return source;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: activeWorkspaceId == null && selectedMenu == 0 && workspaceMenu == 0,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: LayoutBuilder(
        builder: (context, screenConstraints) {
          final compact = screenConstraints.maxWidth < 900;

          return Scaffold(
            backgroundColor: const Color(0xFF0C0D0F),
            drawer: compact
                ? Drawer(
              width: screenConstraints.maxWidth < 420
                  ? screenConstraints.maxWidth * 0.86
                  : 340,
              backgroundColor: const Color(0xFF111214),
              child: SafeArea(child: _buildSidebar()),
            )
                : null,
            body: SafeArea(
              child: Row(
                children: [
                  if (!compact && sidebarExpanded) _buildSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar() {
    final all = orders;
    final harexaCount = all.where((o) => o.workspaceId == 'harexaart').length;
    final lavanyaCount = all.where((o) => o.workspaceId == 'lavanya_art').length;
    final finishedCount = all.where((o) => o.workspaceId == activeWorkspaceId && o.keeperStage == KeeperStage.selesaiDikerjakan && o.paymentStatus == PaymentStatus.belumDibayar).length;
    final archiveCount = all.where((o) => o.workspaceId == activeWorkspaceId && o.keeperStage == KeeperStage.selesaiDikerjakan && o.paymentStatus == PaymentStatus.sudahDibayar).length;

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF111214),
        border: Border(right: BorderSide(color: Color(0xFF25272B))),
      ),
      child: Column(
        children: [
          _buildLogo(),
          const Divider(height: 1, color: Color(0xFF25272B)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          title: 'Control Center',
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          selected: activeWorkspaceId == null && selectedMenu == 0,
                          onTap: () => setState(() { activeWorkspaceId = null; selectedMenu = 0; workspaceMenu = 0; }),
                        ),
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          title: 'HarexaArt',
                          icon: Icons.auto_awesome_outlined,
                          activeIcon: Icons.auto_awesome,
                          selected: activeWorkspaceId == 'harexaart',
                          trailing: '$harexaCount',
                          onTap: () => _openWorkspace('harexaart'),
                        ),
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          title: 'Lavanya Art',
                          icon: Icons.palette_outlined,
                          activeIcon: Icons.palette,
                          selected: activeWorkspaceId == 'lavanya_art',
                          trailing: '$lavanyaCount',
                          onTap: () => _openWorkspace('lavanya_art'),
                        ),
                      ],
                    ),
                  ),
                  if (activeWorkspaceId != null) ...[
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _activeWorkspaceName.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF5F636A), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          _workspaceMenuItem(0, 'Dashboard', Icons.dashboard_outlined),
                          _workspaceMenuItem(1, 'Orderan Masuk', Icons.inventory_2_outlined),
                          _workspaceMenuItem(2, 'Sedang Dikerjakan', Icons.autorenew),
                          _workspaceMenuItem(3, 'Siap Dikirim', Icons.local_shipping_outlined, badge: shippingCountForWorkspace),
                          _workspaceMenuItem(4, 'Selesai', Icons.check_circle_outline, badge: finishedCount),
                          _workspaceMenuItem(5, 'Tracking Order', Icons.route_outlined),
                          _workspaceMenuItem(6, 'Monitoring Keuangan', Icons.account_balance_wallet_outlined),
                          _workspaceMenuItem(7, 'Arsipan', Icons.archive_outlined, badge: archiveCount),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF25272B)),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF1C1E22), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_outline, color: Color(0xFFB8BBC1), size: 20)),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('KEEPER', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('Production Team', style: TextStyle(color: Color(0xFF6E7279), fontSize: 9)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int get shippingCountForWorkspace => _visibleOrders.where((o) => o.status == 'SIAP DIKIRIM').length;

  Widget _workspaceMenuItem(int index, String title, IconData icon, {int badge = 0}) {
    final selected = workspaceMenu == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _buildMenuItem(
        title: title,
        icon: icon,
        activeIcon: icon,
        selected: selected,
        trailing: badge > 0 ? '$badge' : null,
        onTap: () => setState(() { workspaceMenu = index; _financeSection = 'overview'; }),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      height: 88,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF202226),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF32353A),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFFD9B55F),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'HAREXAART',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required IconData activeIcon,
    required bool selected,
    required VoidCallback onTap,
    String? trailing,
  }) {
    return Material(
      color: selected ? const Color(0xFF24262A) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(
                selected ? activeIcon : icon,
                color: selected
                    ? const Color(0xFFD9B55F)
                    : const Color(0xFF898D94),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color:
                    selected ? Colors.white : const Color(0xFF92959B),
                    fontSize: 13,
                    fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFD9B55F)
                        : const Color(0xFF292C31),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailing,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF121316)
                          : const Color(0xFFB8BBC1),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    final title = activeWorkspaceId == null
        ? 'Keeper Control Center'
        : '${_activeWorkspaceName} • ${_workspaceTitle(workspaceMenu)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final veryCompact = constraints.maxWidth < 520;

        return Container(
          height: veryCompact ? 68 : 76,
          padding: EdgeInsets.symmetric(horizontal: veryCompact ? 8 : 18),
          decoration: const BoxDecoration(
            color: Color(0xFF111214),
            border: Border(bottom: BorderSide(color: Color(0xFF25272B)),),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kembali',
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFB9BCC2)),
              ),
              Container(width: 1, height: 24, color: const Color(0xFF292C30)),
              const SizedBox(width: 2),
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: compact
                      ? 'Buka menu'
                      : (sidebarExpanded ? 'Tutup sidebar' : 'Buka sidebar'),
                  onPressed: compact
                      ? () => Scaffold.of(buttonContext).openDrawer()
                      : () => setState(() => sidebarExpanded = !sidebarExpanded),
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFFB9BCC2)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: veryCompact ? 15 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (!veryCompact)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191B1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF292C30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Color(0xFF50B477)),
                      SizedBox(width: 7),
                      Text(
                        'ONLINE',
                        style: TextStyle(
                          color: Color(0xFFC4C7CC),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!veryCompact) const SizedBox(width: 8),
              IconButton(
                tooltip: 'Notifikasi',
                onPressed: () => _showMessage('Belum ada notifikasi baru.'),
                icon: const Icon(Icons.notifications_none, color: Color(0xFFB9BCC2)),
              ),
              if (!veryCompact) ...[
                const SizedBox(width: 4),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1F23),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFFB9BCC2),
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _workspaceTitle(int index) {
    const titles = ['Dashboard', 'Orderan Masuk', 'Sedang Dikerjakan', 'Siap Dikirim', 'Selesai', 'Tracking Order', 'Monitoring Keuangan', 'Arsipan'];
    return titles[index.clamp(0, titles.length - 1)];
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      thickness: 7,
      radius: const Radius.circular(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final horizontal = compact ? 12.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, compact ? 14 : 24, horizontal, compact ? 28 : 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: activeWorkspaceId == null
                    ? _buildControlCenter()
                    : _buildWorkspaceContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlCenter() {
    final all = orders;
    final harexa = all.where((o) => o.workspaceId == 'harexaart').toList();
    final lavanya = all.where((o) => o.workspaceId == 'lavanya_art').toList();
    final unfinishedH = harexa.where((o) => o.keeperStage != KeeperStage.selesaiDikerjakan).fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final unfinishedL = lavanya.where((o) => o.keeperStage != KeeperStage.selesaiDikerjakan).fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final finishedH = harexa.where((o) => o.keeperStage == KeeperStage.selesaiDikerjakan).fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final finishedL = lavanya.where((o) => o.keeperStage == KeeperStage.selesaiDikerjakan).fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final urgent = all.where((o) => o.keeperStage != KeeperStage.selesaiDikerjakan && o.daysRemaining == 1).toList()..sort((a,b) => a.finishDate.compareTo(b.finishDate));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(title: 'Keeper Control Center', subtitle: 'Satu tampilan untuk memantau HarexaArt dan Lavanya Art tanpa mencampur nominal keduanya.'),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          if (compact) {
            return Column(
              children: [
                _buildBrandSummaryCard('HarexaArt', harexa.length, unfinishedH, finishedH, Icons.auto_awesome, 'harexaart'),
                const SizedBox(height: 12),
                _buildBrandSummaryCard('Lavanya Art', lavanya.length, unfinishedL, finishedL, Icons.palette_outlined, 'lavanya_art'),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _buildBrandSummaryCard('HarexaArt', harexa.length, unfinishedH, finishedH, Icons.auto_awesome, 'harexaart')),
              const SizedBox(width: 14),
              Expanded(child: _buildBrandSummaryCard('Lavanya Art', lavanya.length, unfinishedL, finishedL, Icons.palette_outlined, 'lavanya_art')),
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _buildSummaryCard(title: 'TOTAL ORDER', value: '${all.length}', icon: Icons.inventory_2_outlined),
        _buildSummaryCard(title: 'BELUM SELESAI', value: _formatRupiah(unfinishedH + unfinishedL), icon: Icons.timelapse_outlined),
        _buildSummaryCard(title: 'SUDAH SELESAI', value: _formatRupiah(finishedH + finishedL), icon: Icons.check_circle_outline),
      ]),
      const SizedBox(height: 24),
      _buildDeadlineMonitor(urgent),
    ]);
  }

  Widget _buildBrandSummaryCard(String name, int count, int unfinished, int finished, IconData icon, String workspaceId) {
    return InkWell(
      onTap: () => _openWorkspace(workspaceId),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF15171A), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF292C31))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF202226), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: const Color(0xFFD9B55F))), const SizedBox(width: 12), Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))), const Icon(Icons.arrow_forward_rounded, color: Color(0xFF666A71), size: 18)]),
          const SizedBox(height: 18),
          Text('$count order', style: const TextStyle(color: Color(0xFF9B9EA4), fontSize: 11)),
          const SizedBox(height: 10),
          Wrap(spacing: 22, runSpacing: 10, children: [
            _miniMoney('Belum selesai', unfinished),
            _miniMoney('Sudah selesai', finished),
          ]),
        ]),
      ),
    );
  }

  Widget _miniMoney(String label, int amount) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF60646B), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .7)), const SizedBox(height: 4), Text(_formatRupiah(amount), style: const TextStyle(color: Color(0xFFD2D4D8), fontSize: 13, fontWeight: FontWeight.w700))]);

  Widget _buildDeadlineMonitor(List<_KeeperOrder> urgent) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF15171A), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF5A4A28))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.notification_important_outlined, color: Color(0xFFD9B55F), size: 21), const SizedBox(width: 9), const Expanded(child: Text('MONITORING DEADLINE • H-1', style: TextStyle(color: Color(0xFFD9B55F), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8))), Text('${urgent.length} order', style: const TextStyle(color: Color(0xFF9B9EA4), fontSize: 10, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 8),
      const Text('Order yang tepat 1 hari sebelum deadline. Review gambar sebelum produksi dilanjutkan.', style: TextStyle(color: Color(0xFF898D94), fontSize: 11)),
      const SizedBox(height: 14),
      if (urgent.isEmpty) const Text('Tidak ada order H-1 saat ini.', style: TextStyle(color: Color(0xFF6F737A), fontSize: 11)) else ...urgent.map((o) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildUrgentOrder(o))),
    ]));
  }

  Widget _buildUrgentOrder(_KeeperOrder order) {
    return Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFF111315), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF292C31))), child: Row(children: [
      _buildProductThumb(order, 54), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${order.workspaceName} • ${order.id}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('${order.ukuran} • ${order.frame} • deadline ${_formatDate(order.finishDate)}', style: const TextStyle(color: Color(0xFF858990), fontSize: 9), overflow: TextOverflow.ellipsis)])), const SizedBox(width: 8), OutlinedButton.icon(onPressed: () => _showProductImage(order), icon: const Icon(Icons.visibility_outlined, size: 15), label: const Text('REVIEW GAMBAR'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD9B55F), side: const BorderSide(color: Color(0xFF5A4A28)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))
    ]));
  }

  bool _hasProductImage(_KeeperOrder order) {
    final bytes = order.productImage;
    return (bytes != null && bytes.isNotEmpty) ||
        (order.productImageUrl != null &&
            order.productImageUrl!.trim().isNotEmpty);
  }

  Widget _productImageWidget(
      _KeeperOrder order, {
        BoxFit fit = BoxFit.cover,
      }) {
    final bytes = order.productImage;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF656970),
        ),
      );
    }

    final url = order.productImageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF656970),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      );
    }

    return const Icon(
      Icons.image_outlined,
      color: Color(0xFF656970),
    );
  }

  Widget _buildProductThumb(_KeeperOrder order, double size) {
    final hasImage = _hasProductImage(order);
    return InkWell(
      onTap: hasImage ? () => _showProductImage(order) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF202226),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF303339)),
        ),
        child: _productImageWidget(order),
      ),
    );
  }

  Widget _buildProductPreviewHero(_KeeperOrder order) {
    final hasImage = _hasProductImage(order);

    return InkWell(
      onTap: hasImage ? () => _showProductImage(order) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 230,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF111315),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF303339)),
        ),
        child: hasImage
            ? Stack(
          fit: StackFit.expand,
          children: [
            _productImageWidget(
              order,
              fit: BoxFit.contain,
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xDD111315),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFF5A4A28)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in,
                      color: Color(0xFFD9B55F),
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'KLIK GAMBAR UNTUK REVIEW',
                      style: TextStyle(
                        color: Color(0xFFD9B55F),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
            : const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF656970),
              size: 42,
            ),
            SizedBox(height: 9),
            Text(
              'Gambar produk belum tersedia',
              style: TextStyle(
                color: Color(0xFF777B82),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductImage(_KeeperOrder order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF111214),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 850,
              maxHeight: 720,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${order.workspaceName} • ${order.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF8D9198),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: !_hasProductImage(order)
                        ? const Center(
                      child: Text(
                        'Gambar order belum tersedia.',
                        style: TextStyle(
                          color: Color(0xFF858990),
                        ),
                      ),
                    )
                        : InteractiveViewer(
                      child: _productImageWidget(
                        order,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order.ukuran} • ${order.frame}',
                    style: const TextStyle(
                      color: Color(0xFF898D94),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _orderPrice(_KeeperOrder order) => order.price ?? 0;
  String _formatRupiah(int value) {
    final text = value.toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, text.substring(start, i));
    }
    return 'Rp ${parts.join('.')}';
  }

  Widget _buildWorkspaceContent() {
    final list = _visibleOrders;

    switch (workspaceMenu) {
      case 1:
        return _buildWorkspaceList(
          'Orderan Masuk',
          list.where((o) => o.keeperStage == KeeperStage.orderanMasuk).toList(),
        );
      case 2:
        return _buildWorkspaceList(
          'Sedang Dikerjakan',
          list.where((o) => o.keeperStage == KeeperStage.sedangDikerjakan).toList(),
        );
      case 3:
        return _buildWorkspaceList(
          'Siap Dikirim',
          list.where((o) => o.keeperStage == KeeperStage.inputResi).toList(),
          shippingPage: true,
        );
      case 4:
        return _buildWorkspaceList(
          'Selesai',
          list.where((o) =>
          o.keeperStage == KeeperStage.selesaiDikerjakan &&
              o.paymentStatus == PaymentStatus.belumDibayar).toList(),
        );
      case 5:
        return _buildTrackingWorkspace(list);
      case 6:
        return _buildFinanceWorkspace(list);
      case 7:
        return _buildArchiveWorkspace(list);
      default:
        return _buildWorkspaceDashboard(list);
    }
  }

  Widget _buildWorkspaceDashboard(List<_KeeperOrder> list) {
    final incoming =
        list.where((o) => o.keeperStage == KeeperStage.orderanMasuk).length;
    final progress =
        list.where((o) => o.keeperStage == KeeperStage.sedangDikerjakan).length;
    final ready =
        list.where((o) => o.keeperStage == KeeperStage.inputResi).length;
    final done = list
        .where(
          (o) =>
      o.keeperStage == KeeperStage.selesaiDikerjakan &&
          o.paymentStatus == PaymentStatus.belumDibayar,
    )
        .length;

    final urgent = list
        .where(
          (o) =>
      o.keeperStage != KeeperStage.selesaiDikerjakan &&
          o.daysRemaining == 1,
    )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: _activeWorkspaceName,
          subtitle:
          'Workspace khusus $_activeWorkspaceName. Semua angka dan status dibaca dari OrderStore.',
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(
              title: 'ORDERAN MASUK',
              value: '$incoming',
              icon: Icons.inventory_2_outlined,
            ),
            _buildSummaryCard(
              title: 'SEDANG DIKERJAKAN',
              value: '$progress',
              icon: Icons.autorenew,
            ),
            _buildSummaryCard(
              title: 'SIAP DIKIRIM',
              value: '$ready',
              icon: Icons.local_shipping_outlined,
            ),
            _buildSummaryCard(
              title: 'SELESAI',
              value: '$done',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDeadlineMonitor(urgent),
      ],
    );
  }

  Widget _buildWorkspaceList(String title, List<_KeeperOrder> list, {bool shippingPage = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildHeader(title: title, subtitle: 'Data $_activeWorkspaceName • ${list.length} order'), const SizedBox(height: 22), if (list.isEmpty) _buildEmptyState(icon: Icons.inventory_2_outlined, title: 'Belum ada order', message: 'Order akan tampil otomatis ketika tersedia di OrderStore.') else ...list.map((o) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildOrderCard(o, shippingPage: shippingPage)))]);
  }

  Widget _buildTrackingWorkspace(List<_KeeperOrder> list) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildHeader(title: 'Tracking Order', subtitle: 'Timeline produksi, deadline, dan pengiriman $_activeWorkspaceName.'), const SizedBox(height: 22), ...list.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildTrackingRow(o)))]);
  }

  Widget _buildTrackingRow(_KeeperOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF292C31),
        ),
      ),
      child: Row(
        children: [
          _buildProductThumb(order, 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(order.receivedAt)} → ${_formatDate(order.finishDate)}',
                  style: const TextStyle(
                    color: Color(0xFF858990),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatus(order.status),
              const SizedBox(height: 5),
              Text(
                order.completedAt == null
                    ? 'Belum selesai'
                    : 'Selesai ${_formatDate(order.completedAt!)}',
                style: const TextStyle(
                  color: Color(0xFF6F737A),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _financeSection = 'overview';

  Widget _buildFinanceWorkspace(List<_KeeperOrder> list) {
    // Monitoring Keuangan adalah menu global Keeper.
    // Jangan dibatasi oleh workspace yang sedang aktif agar HarexaArt dan
    // Lavanya Art tetap bisa dipantau dari satu halaman finance.
    final financeOrders = orders.toList();
    final harexa = financeOrders.where((o) => o.workspaceId == 'harexaart').toList();
    final lavanya = financeOrders.where((o) => o.workspaceId == 'lavanya_art').toList();

    if (_financeSection == 'harexa') {
      return _buildFinanceBrandDetail(
        title: 'HarexaArt',
        workspaceId: 'harexaart',
        list: harexa,
      );
    }

    if (_financeSection == 'lavanya') {
      return _buildFinanceBrandDetail(
        title: 'Lavanya Art',
        workspaceId: 'lavanya_art',
        list: lavanya,
      );
    }

    if (_financeSection == 'progress') {
      return _buildFinanceStatusDetail(
        title: 'Sedang Dikerjakan',
        subtitle: 'Order yang sedang dikerjakan Keeper saat ini.',
        list: financeOrders
            .where((o) => o.keeperStage == KeeperStage.sedangDikerjakan)
            .toList(),
        icon: Icons.autorenew,
      );
    }

    if (_financeSection == 'paid') {
      return _buildFinancePaidDetail(financeOrders);
    }

    final progress = financeOrders
        .where((o) => o.keeperStage == KeeperStage.sedangDikerjakan)
        .toList();
    final paid = financeOrders
        .where((o) =>
    o.keeperStage == KeeperStage.selesaiDikerjakan &&
        o.paymentStatus == PaymentStatus.sudahDibayar)
        .toList();

    final harexaTotal = harexa.fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final lavanyaTotal = lavanya.fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final progressTotal = progress.fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final paidTotal = paid.fold<int>(0, (sum, o) => sum + _orderPrice(o));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Tracking Keuangan',
          subtitle:
          'Pilih brand atau status untuk melihat jumlah order dan nominal. Keeper bersifat read-only.',
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _buildFinanceNavigationCard(
                title: 'HarexaArt',
                subtitle: 'Order dan nominal HarexaArt',
                count: harexa.length,
                amount: harexaTotal,
                icon: Icons.auto_awesome,
                onTap: () => setState(() => _financeSection = 'harexa'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildFinanceNavigationCard(
                title: 'Lavanya Art',
                subtitle: 'Order dan nominal Lavanya Art',
                count: lavanya.length,
                amount: lavanyaTotal,
                icon: Icons.palette_outlined,
                onTap: () => setState(() => _financeSection = 'lavanya'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildFinanceNavigationCard(
                title: 'Sedang Dikerjakan',
                subtitle: 'Order yang masih berjalan di produksi',
                count: progress.length,
                amount: progressTotal,
                icon: Icons.autorenew,
                onTap: () => setState(() => _financeSection = 'progress'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildFinanceNavigationCard(
                title: 'Sudah Dibayar',
                subtitle: 'Order yang sudah dilunasi Admin',
                count: paid.length,
                amount: paidTotal,
                icon: Icons.verified_outlined,
                onTap: () => setState(() => _financeSection = 'paid'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFinanceReadOnlyNote(),
      ],
    );
  }

  Widget _buildFinanceNavigationCard({
    required String title,
    required String subtitle,
    required int count,
    required int amount,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF15171A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF292C31)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF202226),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: const Color(0xFFD9B55F)),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF666A71),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _financeMetric('JUMLAH ORDER', '$count'),
                  ),
                  Expanded(
                    child: _financeMetric('NOMINAL', _formatRupiah(amount)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _financeMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF60646B),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD9B55F),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceBrandDetail({
    required String title,
    required String workspaceId,
    required List<_KeeperOrder> list,
  }) {
    final active = list.where((o) => o.keeperStage != KeeperStage.selesaiDikerjakan).toList();
    final processed = list.where((o) =>
    o.keeperStage == KeeperStage.selesaiDikerjakan &&
        o.paymentStatus == PaymentStatus.belumDibayar).toList();
    final paid = list.where((o) =>
    o.keeperStage == KeeperStage.selesaiDikerjakan &&
        o.paymentStatus == PaymentStatus.sudahDibayar).toList();
    final total = list.fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final processedTotal = processed.fold<int>(0, (sum, o) => sum + _orderPrice(o));
    final paidTotal = paid.fold<int>(0, (sum, o) => sum + _orderPrice(o));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFinanceBackButton(),
        const SizedBox(height: 14),
        _buildHeader(
          title: title,
          subtitle: 'Ringkasan keuangan $title. Semua nominal dibaca dari OrderStore.',
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(title: 'TOTAL ORDER', value: '${list.length}', icon: Icons.inventory_2_outlined),
            _buildSummaryCard(title: 'TOTAL NOMINAL', value: _formatRupiah(total), icon: Icons.payments_outlined),
            _buildSummaryCard(title: 'BELUM SELESAI', value: _formatRupiah(active.fold<int>(0, (sum, o) => sum + _orderPrice(o))), icon: Icons.timelapse_outlined),
            _buildSummaryCard(title: 'SUDAH DIPROSES', value: _formatRupiah(processedTotal), icon: Icons.task_alt_outlined),
            _buildSummaryCard(title: 'SUDAH DIBAYAR', value: _formatRupiah(paidTotal), icon: Icons.verified_outlined),
          ],
        ),
        const SizedBox(height: 22),
        if (list.isEmpty)
          _buildEmptyState(icon: Icons.account_balance_wallet_outlined, title: 'Belum ada data', message: 'Belum ada order pada workspace $title.')
        else
          ...list.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFinanceOrderRow(o),
          )),
      ],
    );
  }

  Widget _buildFinanceStatusDetail({
    required String title,
    required String subtitle,
    required List<_KeeperOrder> list,
    required IconData icon,
  }) {
    final total = list.fold<int>(0, (sum, o) => sum + _orderPrice(o));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFinanceBackButton(),
        const SizedBox(height: 14),
        _buildHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(title: 'JUMLAH ORDER', value: '${list.length}', icon: icon),
            _buildSummaryCard(title: 'TOTAL NOMINAL', value: _formatRupiah(total), icon: Icons.payments_outlined),
          ],
        ),
        const SizedBox(height: 22),
        if (list.isEmpty)
          _buildEmptyState(icon: icon, title: 'Tidak ada order', message: 'Belum ada order pada status ini.')
        else
          ...list.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFinanceOrderRow(o),
          )),
      ],
    );
  }

  Widget _buildFinancePaidDetail(List<_KeeperOrder> list) {
    final paid = list
        .where((o) =>
    o.keeperStage == KeeperStage.selesaiDikerjakan &&
        o.paymentStatus == PaymentStatus.sudahDibayar)
        .toList()
      ..sort((a, b) {
        final ad = a.paidAt ?? a.completedAt ?? a.receivedAt;
        final bd = b.paidAt ?? b.completedAt ?? b.receivedAt;
        return bd.compareTo(ad);
      });

    final total = paid.fold<int>(0, (sum, o) => sum + _orderPrice(o));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFinanceBackButton(),
        const SizedBox(height: 14),
        _buildHeader(
          title: 'Sudah Dibayar',
          subtitle: 'Seluruh order yang telah dilunasi Admin. Keeper dapat mengunduh satu PDF gabungan.',
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'JUMLAH ORDER',
                value: '${paid.length}',
                icon: Icons.verified_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'TOTAL DIBAYAR',
                value: _formatRupiah(total),
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: paid.isEmpty ? null : () => _downloadPaidPaymentsPdf(paid),
            icon: const Icon(Icons.download_outlined),
            label: const Text('DOWNLOAD 1 PDF KESELURUHAN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9B55F),
              foregroundColor: const Color(0xFF121316),
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (paid.isEmpty)
          _buildEmptyState(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Belum ada pembayaran',
            message: 'Saat Admin melakukan pelunasan, order akan otomatis masuk ke sini.',
          )
        else
          ...paid.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFinanceOrderRow(o),
          )),
      ],
    );
  }

  Widget _buildFinanceOrderRow(_KeeperOrder order) {
    final status = order.paymentStatus == PaymentStatus.sudahDibayar
        ? 'SUDAH DIBAYAR'
        : order.keeperStage == KeeperStage.selesaiDikerjakan
        ? 'SUDAH DIPROSES'
        : 'SEDANG BERJALAN';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF292C31)),
      ),
      child: Row(
        children: [
          _buildProductThumb(order, 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 4),
                Text('${order.productName} • ${order.ukuran} • ${order.frame}', style: const TextStyle(color: Color(0xFF858990), fontSize: 9), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('$status • ${_formatDate(order.paidAt ?? order.completedAt)}', style: const TextStyle(color: Color(0xFF6F737A), fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_formatRupiah(_orderPrice(order)), style: const TextStyle(color: Color(0xFFD9B55F), fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFinanceBackButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _financeSection = 'overview'),
      icon: const Icon(Icons.arrow_back_rounded, size: 17),
      label: const Text('KEMBALI KE TRACKING KEUANGAN'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD9B55F),
        side: const BorderSide(color: Color(0xFF5A4A28)),
      ),
    );
  }

  Widget _buildFinanceReadOnlyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF292C31)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Color(0xFFD9B55F), size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tracking Keuangan Keeper bersifat read-only. Keeper tidak dapat membayar, mengubah nominal, atau menghapus data. Perubahan pembayaran dari Admin akan terbaca otomatis melalui OrderStore.',
              style: TextStyle(color: Color(0xFF858990), fontSize: 10, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPaidPaymentsPdf(List<_KeeperOrder> paidOrders) async {
    if (paidOrders.isEmpty) {
      _showMessage('Belum ada order yang sudah dibayar.');
      return;
    }

    try {
      final sorted = [...paidOrders]
        ..sort((a, b) {
          final ad = a.paidAt ?? a.completedAt ?? a.receivedAt;
          final bd = b.paidAt ?? b.completedAt ?? b.receivedAt;
          return ad.compareTo(bd);
        });

      final total = sorted.fold<int>(0, (sum, order) => sum + _orderPrice(order));
      final document = pw.Document();
      final generatedAt = DateTime.now();

      document.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: .7, color: pdf.PdfColors.grey400),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'HAREXAART SYSTEM',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'LAPORAN PELUNASAN PEMBAYARAN KEEPER',
                        style: const pw.TextStyle(fontSize: 8, color: pdf.PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  _formatDate(generatedAt),
                  style: const pw.TextStyle(fontSize: 7.5, color: pdf.PdfColors.grey700),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: .5, color: pdf.PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'HarexaArt • Keeper Finance • Read Only',
                    style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey600),
                  ),
                ),
                pw.Text(
                  'Halaman ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey600),
                ),
              ],
            ),
          ),
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Text(
                'DAFTAR PEMBAYARAN LUNAS',
                style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                activeWorkspaceId == null
                    ? 'HarexaArt + Lavanya Art'
                    : _activeWorkspaceName,
                style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.grey700),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey100,
                  border: pw.Border.all(color: pdf.PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(7),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TOTAL ORDER', style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey600)),
                          pw.SizedBox(height: 4),
                          pw.Text('${sorted.length}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TOTAL DILUNASI', style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey600)),
                          pw.SizedBox(height: 4),
                          pw.Text(_formatRupiah(total), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
            ];

            for (var index = 0; index < sorted.length; index++) {
              final order = sorted[index];
              final image = order.productImage;
              final imageWidget = image == null
                  ? pw.Container(
                width: 72,
                height: 72,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey100,
                  border: pw.Border.all(color: pdf.PdfColors.grey300),
                ),
                child: pw.Text('NO IMAGE', style: pw.TextStyle(fontSize: 7)),
              )
                  : pw.Container(
                width: 72,
                height: 72,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdf.PdfColors.grey300),
                ),
                child: pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.cover),
              );

              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(11),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: pdf.PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(7),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      imageWidget,
                      pw.SizedBox(width: 11),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    '${(index + 1).toString().padLeft(2, '0')} • ${order.id}',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                ),
                                pw.Text(
                                  'LUNAS',
                                  style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 6),
                            _keeperPdfRow('Workspace', order.workspaceName),
                            _keeperPdfRow('Produk', order.productName),
                            _keeperPdfRow('Ukuran', order.ukuran),
                            _keeperPdfRow('Frame', order.frame),
                            _keeperPdfRow('Keterangan', order.catatan.trim().isEmpty ? '-' : order.catatan),
                            _keeperPdfRow('Harga Final', _formatRupiah(_orderPrice(order))),
                            pw.SizedBox(height: 5),
                            _keeperPdfRow('Order Masuk', _formatDate(order.receivedAt)),
                            _keeperPdfRow('Keeper Selesai', _formatDate(order.completedAt)),
                            _keeperPdfRow('Admin Bayar', _formatDate(order.paidAt)),
                            _keeperPdfRow('Jasa Kirim', order.shippingCourier ?? '-'),
                            _keeperPdfRow('Tanggal Kirim', _formatDate(order.shippingDate)),
                            _keeperPdfRow('Bukti Resi', order.shippingReceiptFileName ?? '-'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (index != sorted.length - 1) {
                widgets.add(pw.SizedBox(height: 10));
              }
            }

            widgets.add(pw.SizedBox(height: 16));
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdf.PdfColors.grey500),
                  borderRadius: pw.BorderRadius.circular(7),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'TOTAL PELUNASAN',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Text(
                      _formatRupiah(total),
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );

            return widgets;
          },
        ),
      );

      final bytes = await document.save();
      final safeDate = generatedAt.toIso8601String().substring(0, 10).replaceAll('-', '');
      final safeWorkspace = activeWorkspaceId == null
          ? 'harexaart_lavanya_art'
          : activeWorkspaceId!;
      final fileName = 'keeper_pelunasan_${safeWorkspace}_$safeDate.pdf';

      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      _showMessage('1 PDF keseluruhan berhasil dibuat dan download dimulai.');
    } catch (error) {
      _showMessage('PDF pembayaran gagal dibuat: $error', isError: true);
    }
  }

  pw.Widget _keeperPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 6.7, color: pdf.PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 6.7, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveWorkspace(List<_KeeperOrder> list) {
    // Arsip mengikuti OrderStore yang sama. Order baru masuk ke arsip
    // hanya setelah Keeper selesai DAN Admin memfinalisasi pembayaran.
    final archived = list
        .where(
          (o) =>
      o.keeperStage == KeeperStage.selesaiDikerjakan &&
          o.paymentStatus == PaymentStatus.sudahDibayar,
    )
        .toList()
      ..sort((a, b) {
        final ad = a.paidAt ?? a.completedAt ?? a.receivedAt;
        final bd = b.paidAt ?? b.completedAt ?? b.receivedAt;
        return bd.compareTo(ad);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Arsipan',
          subtitle:
          'Order yang sudah selesai dan sudah dibayar Admin. Data hanya untuk dilihat dan diunduh.',
        ),
        const SizedBox(height: 22),
        _buildArchiveSummary(archived.length),
        const SizedBox(height: 20),
        if (archived.isEmpty)
          _buildEmptyState(
            icon: Icons.archive_outlined,
            title: 'Belum ada arsip',
            message:
            'Order akan otomatis pindah ke Arsipan setelah Admin memfinalisasi pembayaran.',
          )
        else
          ...archived.map(
                (order) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildArchiveCard(order),
            ),
          ),
      ],
    );
  }

  Widget _buildArchiveSummary(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF315A45)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF193324),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.archive_outlined,
              color: Color(0xFF65C58B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL ARSIP',
                  style: TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count order',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline,
            color: Color(0xFF65C58B),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveCard(_KeeperOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF292C31)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    order.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _archiveBadge('SUDAH DIBAYAR'),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                order.productName,
                style: const TextStyle(
                  color: Color(0xFFC8CAD0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${order.ukuran} • ${order.frame}',
                style: const TextStyle(
                  color: Color(0xFF858990),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                order.catatan.trim().isEmpty
                    ? 'Tidak ada keterangan order.'
                    : order.catatan,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 16,
                runSpacing: 7,
                children: [
                  _archiveMeta('ORDER', _formatDate(order.receivedAt)),
                  _archiveMeta(
                    'SELESAI',
                    order.completedAt == null
                        ? '-'
                        : _formatDate(order.completedAt!),
                  ),
                  _archiveMeta(
                    'DIBAYAR',
                    order.paidAt == null ? '-' : _formatDate(order.paidAt!),
                  ),
                  _archiveMeta(
                    'NOMINAL',
                    _formatRupiah(_orderPrice(order)),
                  ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showArchiveDetail(order),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('LIHAT ARSIP'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBFC2C7),
                  side: const BorderSide(color: Color(0xFF303339)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _downloadArchivePdf(order),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('DOWNLOAD PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9B55F),
                  foregroundColor: const Color(0xFF121316),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductThumb(order, 72),
                    const SizedBox(width: 13),
                    Expanded(child: info),
                  ],
                ),
                const SizedBox(height: 13),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductThumb(order, 86),
              const SizedBox(width: 15),
              Expanded(child: info),
              const SizedBox(width: 15),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _archiveBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF193324),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF315A45)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF65C58B),
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _archiveMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5F636A),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFBFC2C7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showArchiveDetail(_KeeperOrder order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF191B1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
              maxHeight: 780,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arsip ${order.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${order.workspaceName} • ${order.productName}',
                                style: const TextStyle(
                                  color: Color(0xFF858990),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF8D9198),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 320,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111315),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0xFF303339)),
                      ),
                      child: !_hasProductImage(order)
                          ? const Center(
                        child: Text(
                          'Gambar produk belum tersedia.',
                          style: TextStyle(
                            color: Color(0xFF777B82),
                          ),
                        ),
                      )
                          : InteractiveViewer(
                        child: _productImageWidget(
                          order,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _archiveDetailSection(
                      title: 'KETERANGAN ORDER',
                      children: [
                        _archiveDetailRow('Produk', order.productName),
                        _archiveDetailRow('Ukuran', order.ukuran),
                        _archiveDetailRow('Frame', order.frame),
                        _archiveDetailRow(
                          'Keterangan',
                          order.catatan.trim().isEmpty
                              ? '-'
                              : order.catatan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _archiveDetailSection(
                      title: 'TIMELINE',
                      children: [
                        _archiveDetailRow(
                          'Order masuk',
                          _formatDate(order.receivedAt),
                        ),
                        _archiveDetailRow(
                          'Keeper selesai',
                          order.completedAt == null
                              ? '-'
                              : _formatDate(order.completedAt!),
                        ),
                        _archiveDetailRow(
                          'Admin bayar',
                          order.paidAt == null
                              ? '-'
                              : _formatDate(order.paidAt!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _archiveDetailSection(
                      title: 'PENGIRIMAN',
                      children: [
                        _archiveDetailRow(
                          'Jasa kirim',
                          order.shippingCourier ?? '-',
                        ),
                        _archiveDetailRow(
                          'Tanggal kirim',
                          order.shippingDate == null
                              ? '-'
                              : _formatDate(order.shippingDate!),
                        ),
                        _archiveDetailRow(
                          'File bukti resi',
                          order.shippingReceiptFileName ?? '-',
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _downloadArchivePdf(order),
                          icon: const Icon(
                            Icons.download_outlined,
                            size: 16,
                          ),
                          label: const Text('DOWNLOAD PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD9B55F),
                            side: const BorderSide(
                              color: Color(0xFF5A4A28),
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
        );
      },
    );
  }

  Widget _archiveDetailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF292C31)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD9B55F),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _archiveDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF656970),
                fontSize: 9,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFC8CAD0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadArchivePdf(_KeeperOrder order) async {
    await _downloadPaidPaymentsPdf([order]);
  }

  void _startKeeperOrder(_KeeperOrder order) {
    final ok = OrderStore.instance.startKeeperWork(
      orderId: order.id,
      workspaceId: order.workspaceId,
    );

    if (!ok) {
      _showMessage(
        'Order ${order.id} tidak bisa dimulai. Data mungkin sudah berubah.',
      );
      return;
    }

    _showMessage(
      'Order ${order.id} masuk ke Sedang Dikerjakan.',
    );
  }

  void _moveToReceiptInput(_KeeperOrder order) {
    final ok = OrderStore.instance.moveKeeperToReceiptInput(
      orderId: order.id,
      workspaceId: order.workspaceId,
    );

    if (!ok) {
      _showMessage(
        'Order ${order.id} belum bisa dipindahkan ke Siap Dikirim.',
      );
      return;
    }

    _showMessage(
      'Order ${order.id} masuk ke Siap Dikirim. Silakan input resi.',
    );
  }

  void _completeOrderNow(_KeeperOrder order) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191B1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Selesaikan Sekarang?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Order ${order.id} dari ${order.workspaceName} sudah selesai dikerjakan dan akan langsung masuk ke menu SELESAI. Data pembayaran tetap BELUM DIBAYAR sampai Finance memprosesnya.',
            style: const TextStyle(
              color: Color(0xFFA5A8AE),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'BATAL',
                style: TextStyle(color: Color(0xFF888C93)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final ok = OrderStore.instance.completeKeeperWorkNow(
                  orderId: order.id,
                  workspaceId: order.workspaceId,
                );

                Navigator.pop(dialogContext);

                if (ok) {
                  _showMessage(
                    'Order ${order.id} selesai dan masuk ke menu SELESAI.',
                  );
                } else {
                  _showMessage(
                    'Order ${order.id} gagal diselesaikan. Data mungkin sudah berubah.',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9B55F),
                foregroundColor: const Color(0xFF121316),
              ),
              child: const Text('SELESAIKAN SEKARANG'),
            ),
          ],
        );
      },
    );
  }

  void _completeOrderFromReadyToShip(_KeeperOrder order) {
    DateTime selectedCompletionDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF191B1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Selesaikan Orderan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ${order.id} sudah berada di SIAP DIKIRIM. Setelah dikonfirmasi, order akan bergabung ke menu SELESAI.',
                    style: const TextStyle(
                      color: Color(0xFFA5A8AE),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'TANGGAL SELESAI / INPUT',
                    style: TextStyle(
                      color: Color(0xFF8D9198),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedCompletionDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFFD9B55F),
                                onPrimary: Color(0xFF121316),
                                surface: Color(0xFF191B1E),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        setDialogState(() {
                          selectedCompletionDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            DateTime.now().hour,
                            DateTime.now().minute,
                          );
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111315),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: const Color(0xFF303339),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            color: Color(0xFFD9B55F),
                            size: 18,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _formatDate(selectedCompletionDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF777B82),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'BATAL',
                    style: TextStyle(color: Color(0xFF888C93)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final ok = OrderStore.instance.completeKeeperWorkFromReceipt(
                      orderId: order.id,
                      workspaceId: order.workspaceId,
                      completionDate: selectedCompletionDate,
                    );

                    Navigator.pop(dialogContext);

                    if (ok) {
                      _showMessage(
                        'Order ${order.id} selesai pada ${_formatDate(selectedCompletionDate)} dan masuk ke menu SELESAI.',
                      );
                    } else {
                      _showMessage(
                        'Order ${order.id} gagal diselesaikan. Pastikan resi sudah tersimpan.',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9B55F),
                    foregroundColor: const Color(0xFF121316),
                  ),
                  child: const Text('SELESAIKAN ORDERAN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // INPUT KE JASA KIRIM
  // ============================================================

  void _inputToShipping(_KeeperOrder order) {
    String? selectedCourier = order.shippingCourier;
    DateTime selectedShippingDate = order.shippingDate ?? DateTime.now();
    Uint8List? selectedReceiptImage = order.shippingReceiptImage;
    String? selectedReceiptFileName = order.shippingReceiptFileName;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickReceipt(ImageSource source) async {
              try {
                final picked = await _imagePicker.pickImage(
                  source: source,
                  imageQuality: 88,
                  maxWidth: 1800,
                );

                if (picked == null) return;

                final bytes = await picked.readAsBytes();

                setDialogState(() {
                  selectedReceiptImage = bytes;
                  selectedReceiptFileName = picked.name;
                });
              } catch (e) {
                _showMessage('Gagal mengambil foto resi. Coba lagi.');
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF191B1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Input ke Jasa Kirim',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.id} • ${order.workspaceName}',
                        style: const TextStyle(
                          color: Color(0xFFD9B55F),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'JASA KIRIM',
                        style: TextStyle(
                          color: Color(0xFF8D9198),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        value: selectedCourier,
                        dropdownColor: const Color(0xFF191B1E),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF777B82),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.local_shipping_outlined,
                            color: Color(0xFF777B82),
                            size: 18,
                          ),
                          hintText: 'Pilih jasa kirim',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6F737A),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF111315),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(
                              color: Color(0xFF303339),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9B55F),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'J&T',
                            child: Text('J&T'),
                          ),
                          DropdownMenuItem(
                            value: 'JNE',
                            child: Text('JNE'),
                          ),
                          DropdownMenuItem(
                            value: 'SiCepat',
                            child: Text('SiCepat'),
                          ),
                          DropdownMenuItem(
                            value: 'AnterAja',
                            child: Text('AnterAja'),
                          ),
                          DropdownMenuItem(
                            value: 'Pos Indonesia',
                            child: Text('Pos Indonesia'),
                          ),
                          DropdownMenuItem(
                            value: 'Lainnya',
                            child: Text('Lainnya'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCourier = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'BUKTI RESI',
                        style: TextStyle(
                          color: Color(0xFF8D9198),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111315),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFF303339),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (selectedReceiptImage != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  selectedReceiptImage!,
                                  width: double.infinity,
                                  height: 210,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                selectedReceiptFileName ?? 'Foto resi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFBFC2C7),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ] else
                              Container(
                                width: double.infinity,
                                height: 130,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17191C),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF292C31),
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      color: Color(0xFF656970),
                                      size: 34,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Belum ada foto bukti resi',
                                      style: TextStyle(
                                        color: Color(0xFF777B82),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    pickReceipt(ImageSource.camera);
                                  },
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('AMBIL FOTO RESI'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD9B55F),
                                    side: const BorderSide(
                                      color: Color(0xFF5A4A28),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    pickReceipt(ImageSource.gallery);
                                  },
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('PILIH FOTO'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFBFC2C7),
                                    side: const BorderSide(
                                      color: Color(0xFF303339),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tanggal Input Pengiriman',
                        style: TextStyle(
                          color: Color(0xFF8D9198),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedShippingDate,
                            firstDate: order.receivedAt,
                            lastDate:
                            DateTime.now().add(const Duration(days: 30)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFD9B55F),
                                    onPrimary: Color(0xFF121316),
                                    surface: Color(0xFF191B1E),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (picked != null) {
                            setDialogState(() {
                              selectedShippingDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111315),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: const Color(0xFF303339),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_outlined,
                                color: Color(0xFFD9B55F),
                                size: 18,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _formatDate(selectedShippingDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF777B82),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242019),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Bukti resi cukup berupa foto atau screenshot. Setelah disimpan, order masuk ke menu Pengiriman dengan status SIAP DIKIRIM. Status belum SELESAI sampai Keeper menekan SELESAI REAL.',
                          style: TextStyle(
                            color: Color(0xFFB4A77F),
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'BATAL',
                    style: TextStyle(
                      color: Color(0xFF888C93),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedCourier == null ||
                        selectedCourier!.trim().isEmpty) {
                      _showMessage('Jasa kirim wajib dipilih.');
                      return;
                    }

                    if (selectedReceiptImage == null) {
                      _showMessage('Foto atau screenshot resi wajib diupload.');
                      return;
                    }

                    // Semua perubahan disimpan langsung ke OrderStore.
                    // Keeper tidak menyimpan salinan data produksinya sendiri.
                    OrderStore.instance.updateShipping(
                      orderId: order.id,
                      courier: selectedCourier!.trim(),
                      receiptImage: selectedReceiptImage!,
                      receiptFileName: selectedReceiptFileName,
                      shippingDate: selectedShippingDate,
                    );

                    Navigator.pop(dialogContext);

                    _showMessage(
                      'Order ${order.id} berhasil diinput ke jasa kirim.',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9B55F),
                    foregroundColor: const Color(0xFF121316),
                  ),
                  child: const Text('SIMPAN PENGIRIMAN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUKA KEMBALI ORDER DARI STATUS SELESAI
  // ============================================================

  void _reopenOrder(_KeeperOrder order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191B1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Kembalikan ke Proses?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Order ${order.id} akan dikembalikan dari SELESAI menjadi SEDANG DIKERJAKAN. Data resi tetap disimpan dan order yang sudah dibayar tidak dapat dibuka kembali.',
            style: const TextStyle(
              color: Color(0xFFA5A8AE),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'BATAL',
                style: TextStyle(color: Color(0xFF888C93)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final ok = OrderStore.instance.reopenKeeperWork(
                  orderId: order.id,
                  workspaceId: order.workspaceId,
                );

                Navigator.pop(dialogContext);

                if (ok) {
                  _showMessage(
                    'Order ${order.id} dikembalikan ke proses.',
                  );
                } else {
                  _showMessage(
                    'Order ${order.id} tidak bisa dikembalikan. Pastikan order belum dibayar dan masih berstatus SELESAI.',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9B55F),
                foregroundColor: const Color(0xFF121316),
              ),
              child: const Text('YA, KEMBALIKAN'),
            ),
          ],
        );
      },
    );
  }

  void _showReceiptPreview(_KeeperOrder order) {
    final bytes = order.shippingReceiptImage;
    final storageUrl = order.shippingReceiptUrl?.trim();

    if ((bytes == null || bytes.isEmpty) &&
        storageUrl != null &&
        storageUrl.isNotEmpty) {
      // Resi yang sudah tersimpan di Supabase dibuka langsung dari Storage.
      // PDF tetap PDF asli; tidak dikonversi menjadi gambar.
      html.window.open(storageUrl, '_blank');
      return;
    }

    if (bytes == null || bytes.isEmpty) {
      _showPreviewDialog(
        title: 'Bukti Resi',
        icon: Icons.receipt_long_outlined,
        message: 'Belum ada file resi untuk order ${order.id}.',
      );
      return;
    }

    // PDF tidak boleh dipaksa masuk Image.memory().
    // Buka sebagai PDF asli di browser agar bisa zoom, download, dan print.
    if (_keeperIsPdfBytes(bytes)) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      Future<void>.delayed(const Duration(minutes: 2), () {
        html.Url.revokeObjectUrl(url);
      });
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF191B1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 720,
              maxHeight: 760,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: Color(0xFFD9B55F),
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Bukti Resi • ${order.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF8D9198),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: const Color(0xFF111315),
                        padding: const EdgeInsets.all(8),
                        child: InteractiveViewer(
                          minScale: .5,
                          maxScale: 5,
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${order.shippingCourier ?? '-'} • ${order.shippingReceiptFileName ?? 'Gambar resi'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8D9198),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPreviewDialog({
    required String title,
    required IconData icon,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF181A1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25272B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFD9B55F),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF858990),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9B55F),
                      foregroundColor: const Color(0xFF121316),
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                    ),
                    child: const Text(
                      'TUTUP',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF7D8188),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildShippingSummary(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF2A2D32),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF202226),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFFD9B55F),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MENUNGGU SELESAI REAL',
                  style: TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$count order siap dikonfirmasi selesai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 50,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF272A2F),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF555960),
            size: 42,
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF777B82),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF272A2F),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFF202226),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFD9B55F),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _buildOrderCard(
      _KeeperOrder order, {
        bool shippingPage = false,
      }) {
    final isFinished =
        order.keeperStage == KeeperStage.selesaiDikerjakan;
    final isReadyToShip =
        order.keeperStage == KeeperStage.inputResi;
    final isOverdue = order.daysRemaining <= 0 && !isFinished;
    final isSendDateReached =
        order.sendDate.isBefore(_dateOnly(DateTime.now())) ||
            _sameDate(order.sendDate, DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF15171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFinished
              ? const Color(0xFF315A45)
              : isReadyToShip
              ? const Color(0xFF5A4A28)
              : isOverdue
              ? const Color(0xFF6A3838)
              : const Color(0xFF2A2D32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFF202226),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        isReadyToShip
                            ? Icons.local_shipping_outlined
                            : Icons.image_outlined,
                        color: const Color(0xFFD9B55F),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 9,
                            runSpacing: 5,
                            children: [
                              Text(
                                order.workspaceName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF24262A),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  order.id,
                                  style: const TextStyle(
                                    color: Color(0xFF888C93),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Order produksi',
                            style: TextStyle(
                              color: Color(0xFF73777E),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildStatus(order.status),
            ],
          ),
          const SizedBox(height: 18),

          // PREVIEW PRODUK — GAMBAR LANGSUNG TERLIHAT DAN BISA DIKLIK
          _buildProductPreviewHero(order),

          const SizedBox(height: 18),

          // TIMELINE DEADLINE
          _buildDeadlinePanel(
            order: order,
            isOverdue: isOverdue,
            isSendDateReached: isSendDateReached,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF111315),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF24272B),
              ),
            ),
            child: Wrap(
              spacing: 28,
              runSpacing: 15,
              children: [
                _buildInfo(
                  Icons.photo_size_select_small_outlined,
                  'UKURAN',
                  order.ukuran,
                ),
                _buildInfo(
                  Icons.crop_square_outlined,
                  'FRAME',
                  order.frame,
                ),
                _buildInfo(
                  Icons.timelapse_outlined,
                  'DEADLINE',
                  '${order.deadlineDays} Hari',
                ),
                _buildInfo(
                  Icons.calendar_today_outlined,
                  'ORDER MASUK',
                  _formatDate(order.receivedAt),
                ),
                _buildInfo(
                  Icons.event_available_outlined,
                  'HARUS SELESAI',
                  _formatDate(order.finishDate),
                ),
                _buildInfo(
                  Icons.local_shipping_outlined,
                  'HARUS DIKIRIM',
                  _formatDate(order.sendDate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildNote(order.catatan),

          if (order.shippingCourier != null) ...[
            const SizedBox(height: 14),
            _buildShippingInfo(order),
          ],

          const SizedBox(height: 18),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 160,
                child: _buildPreviewButton(
                  icon: Icons.description_outlined,
                  label: 'Lihat Resi',
                  onTap: () {
                    _showReceiptPreview(order);
                  },
                ),
              ),
              _buildCompleteButton(order),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(String status) {
    final isFinished = status == 'SELESAI';
    final isReadyToShip = status == 'SIAP DIKIRIM';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isFinished
            ? const Color(0xFF193324)
            : const Color(0xFF30291A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFinished
              ? const Color(0xFF315A45)
              : const Color(0xFF5A4A28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFinished
                ? Icons.check_circle
                : isReadyToShip
                ? Icons.local_shipping
                : status == 'ORDERAN MASUK'
                ? Icons.inventory_2_outlined
                : Icons.autorenew,
            color: isFinished
                ? const Color(0xFF65C58B)
                : const Color(0xFFD9B55F),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: isFinished
                  ? const Color(0xFF65C58B)
                  : const Color(0xFFD9B55F),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlinePanel({
    required _KeeperOrder order,
    required bool isOverdue,
    required bool isSendDateReached,
  }) {
    if (order.keeperStage == KeeperStage.selesaiDikerjakan) {
      return _buildDeadlineMessage(
        icon: Icons.check_circle_outline,
        title: 'ORDER SELESAI SEPENUHNYA',
        message:
        'Produksi dan proses pengiriman sudah dikonfirmasi selesai.',
        positive: true,
      );
    }

    if (order.keeperStage == KeeperStage.inputResi) {
      return _buildDeadlineMessage(
        icon: Icons.local_shipping_outlined,
        title: 'SUDAH DIINPUT KE JASA KIRIM',
        message:
        'Order sudah masuk proses pengiriman. Tunggu/konfirmasi sampai pengiriman benar-benar selesai.',
        positive: false,
      );
    }

    if (isOverdue) {
      return _buildDeadlineMessage(
        icon: Icons.warning_amber_rounded,
        title: 'DEADLINE SUDAH TIBA / TERLEWAT',
        message:
        'Order sudah mencapai batas deadline. Input ke jasa kirim diprioritaskan, tetapi Keeper tetap boleh menyelesaikan order jika produksi sudah benar-benar selesai.',
        positive: false,
      );
    }

    if (isSendDateReached) {
      return _buildDeadlineMessage(
        icon: Icons.notification_important_outlined,
        title: 'SISA 1 HARI • PERLU PERHATIAN',
        message:
        'Keeper masih bebas menyelesaikan order atau melakukan input ke jasa kirim lebih dulu sesuai kondisi produksi.',
        positive: false,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF17191C),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF292C31),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_outlined,
            color: Color(0xFFD9B55F),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                const Text(
                  'Sisa waktu produksi:',
                  style: TextStyle(
                    color: Color(0xFF8B8F96),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${order.daysRemaining} hari',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  '• Deadline produksi',
                  style: TextStyle(
                    color: Color(0xFF8B8F96),
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatDate(order.sendDate),
                  style: const TextStyle(
                    color: Color(0xFFD9B55F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(
      IconData icon,
      String label,
      String value,
      ) {
    return SizedBox(
      width: 175,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF777B82),
            size: 18,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF656970),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD2D4D8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1E),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notes_outlined,
            color: Color(0xFF6F737A),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                color: Color(0xFF9B9EA4),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 17,
      ),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFBFC2C7),
        side: const BorderSide(
          color: Color(0xFF303339),
        ),
        backgroundColor: const Color(0xFF191B1E),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        textStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCompleteButton(_KeeperOrder order) {
    switch (order.keeperStage) {
      case KeeperStage.orderanMasuk:
        return SizedBox(
          width: 230,
          child: ElevatedButton.icon(
            onPressed: () => _startKeeperOrder(order),
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: const Text(
              'KERJAKAN SEKARANG',
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: const Color(0xFF121316),
              backgroundColor: const Color(0xFFD9B55F),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

      case KeeperStage.sedangDikerjakan:
      // Saat order sudah dikerjakan, DUA tombol penting selalu
      // tersedia: selesaikan sekarang atau input resi.
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: () => _completeOrderNow(order),
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 17,
                ),
                label: const Text(
                  'SELESAIKAN SEKARANG',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFF121316),
                  backgroundColor: const Color(0xFFD9B55F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: OutlinedButton.icon(
                onPressed: () => _inputToShipping(order),
                icon: const Icon(
                  Icons.receipt_long_outlined,
                  size: 17,
                ),
                label: const Text(
                  'INPUT RESI',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD9B55F),
                  side: const BorderSide(
                    color: Color(0xFF5A4A28),
                  ),
                  backgroundColor: const Color(0xFF242019),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );

      case KeeperStage.inputResi:
        final hasReceipt = order.shippingReceiptImage != null &&
            order.shippingCourier != null &&
            order.shippingCourier!.trim().isNotEmpty;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 210,
              child: OutlinedButton.icon(
                onPressed: () => _inputToShipping(order),
                icon: const Icon(
                  Icons.receipt_long_outlined,
                  size: 17,
                ),
                label: Text(
                  hasReceipt ? 'UBAH / LIHAT RESI' : 'INPUT RESI',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD9B55F),
                  side: const BorderSide(
                    color: Color(0xFF5A4A28),
                  ),
                  backgroundColor: const Color(0xFF242019),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: hasReceipt
                    ? () => _completeOrderFromReadyToShip(order)
                    : null,
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 17,
                ),
                label: const Text(
                  'SELESAIKAN ORDERAN',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFF121316),
                  backgroundColor: const Color(0xFFD9B55F),
                  disabledBackgroundColor: const Color(0xFF292C31),
                  disabledForegroundColor: const Color(0xFF666A71),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );

      case KeeperStage.selesaiDikerjakan:
        return SizedBox(
          width: 230,
          child: ElevatedButton.icon(
            onPressed: () => _reopenOrder(order),
            icon: const Icon(Icons.undo_outlined, size: 17),
            label: const Text(
              'KEMBALIKAN KE PROSES',
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: const Color(0xFFD9B55F),
              backgroundColor: const Color(0xFF24262A),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              elevation: 0,
              side: const BorderSide(color: Color(0xFF5A4A28)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildShippingInfo(_KeeperOrder order) {
    final hasReceiptImage = order.shippingReceiptImage != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17191C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF303339),
        ),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildInfo(
            Icons.local_shipping_outlined,
            'JASA KIRIM',
            order.shippingCourier ?? '-',
          ),
          _buildReceiptPreviewSmall(order),
          _buildInfo(
            Icons.event_outlined,
            'TGL INPUT KIRIM',
            order.shippingDate == null
                ? '-'
                : _formatDate(order.shippingDate!),
          ),
          if (!hasReceiptImage)
            const Text(
              'Bukti resi belum tersedia',
              style: TextStyle(
                color: Color(0xFFD06A6A),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeadlineMessage({
    required IconData icon,
    required String title,
    required String message,
    required bool positive,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: positive
            ? const Color(0xFF14271D)
            : const Color(0xFF2B2417),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: positive
              ? const Color(0xFF315A45)
              : const Color(0xFF5A4A28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: positive
                ? const Color(0xFF65C58B)
                : const Color(0xFFD9B55F),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: positive
                        ? const Color(0xFF65C58B)
                        : const Color(0xFFD9B55F),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFA5A8AE),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPreviewSmall(_KeeperOrder order) {
    final bytes = order.shippingReceiptImage;
    final storageUrl = order.shippingReceiptUrl?.trim();
    final hasBytes = bytes != null && bytes.isNotEmpty;
    final hasUrl = storageUrl != null && storageUrl.isNotEmpty;
    final hasFile = hasBytes || hasUrl;
    final fileName = order.shippingReceiptFileName?.toLowerCase() ?? '';
    final isPdf = (hasBytes && _keeperIsPdfBytes(bytes!)) ||
        fileName.endsWith('.pdf');

    return InkWell(
      onTap: hasFile ? () => _showReceiptPreview(order) : null,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF202226),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF303339),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: !hasFile
                ? const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFF777B82),
              size: 21,
            )
                : isPdf
                ? const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFD9B55F),
              size: 23,
            )
                : hasBytes
                ? Image.memory(
              bytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF777B82),
              ),
            )
                : Image.network(
              storageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF777B82),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BUKTI RESI',
                style: TextStyle(
                  color: Color(0xFF656970),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                !hasFile
                    ? 'Belum ada resi'
                    : isPdf
                    ? 'Buka PDF resi'
                    : 'Lihat gambar resi',
                style: TextStyle(
                  color: !hasFile
                      ? const Color(0xFF777B82)
                      : const Color(0xFFD9B55F),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================
// MODEL ORDER
// ============================================================

class _KeeperOrder {
  final String id;
  final String workspaceName;
  final String workspaceId;
  final String productName;
  final String ukuran;
  final String frame;
  final int deadlineDays;
  final DateTime receivedAt;
  final String catatan;
  final int? price;
  final Uint8List? productImage;
  final String? productImageFileName;
  final String? productImageUrl;

  String status;
  final KeeperStage keeperStage;
  final PaymentStatus paymentStatus;
  final DateTime? completedAt;
  final DateTime? paidAt;

  String? shippingCourier;
  Uint8List? shippingReceiptImage;
  String? shippingReceiptFileName;
  String? shippingReceiptUrl;
  DateTime? shippingDate;

  _KeeperOrder({
    required this.id,
    required this.workspaceName,
    required this.workspaceId,
    required this.productName,
    required this.ukuran,
    required this.frame,
    required this.deadlineDays,
    required this.receivedAt,
    required this.catatan,
    this.price,
    this.productImage,
    this.productImageFileName,
    this.productImageUrl,
    required this.status,
    required this.keeperStage,
    required this.paymentStatus,
    this.completedAt,
    this.paidAt,
  });

  DateTime get finishDate {
    return _dateOnlyStatic(
      receivedAt.add(Duration(days: deadlineDays)),
    );
  }

  // Deadline tetap menjadi tanggal acuan produksi.
  // Input ke jasa kirim tidak dikunci oleh tanggal ini; Keeper boleh
  // menginput lebih cepat sesuai kondisi order.
  DateTime get sendDate {
    return finishDate;
  }

  int get daysRemaining {
    final today = _dateOnlyStatic(DateTime.now());
    return finishDate.difference(today).inDays;
  }

  static DateTime _dateOnlyStatic(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}
