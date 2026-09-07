// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../data/order_store.dart';
import '../../../services/global_delete_service.dart';
import 'input_order_page.dart';
import 'edit_order_page.dart';
import 'search_order_page.dart';
import '../finance/finance_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final String adminEmail;
  final String workspaceId;
  final String workspaceName;

  const AdminDashboardPage({
    super.key,
    required this.adminEmail,
    required this.workspaceId,
    required this.workspaceName,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int selectedMenu = 0;
  bool sidebarExpanded = true;
  static const int _monitoringDays = 7;
  Timer? _dashboardClock;

  bool _deleteMode = false;
  bool _deleteBusy = false;
  final Set<String> _selectedDeleteOrderIds = <String>{};

  final menus = const [
    _Menu('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _Menu(
      'Input Order',
      Icons.add_shopping_cart_outlined,
      Icons.add_shopping_cart,
    ),
    _Menu(
      'Pencarian',
      Icons.search_outlined,
      Icons.search,
    ),
    _Menu(
      'Edit Order',
      Icons.edit_note_outlined,
      Icons.edit_note,
    ),
    _Menu(
      'Keuangan',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Refresh setiap menit agar pergantian tanggal otomatis terjadi
    // setelah 00:00 tanpa menunggu ada order baru.
    _dashboardClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _dashboardClock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactLayout = screenWidth < 1050;
    final drawerWidth = screenWidth < 400 ? screenWidth * .86 : 320.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      drawer: compactLayout
          ? Drawer(
        width: drawerWidth,
        child: SafeArea(
          child: _expandedSidebar(width: drawerWidth),
        ),
      )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!compactLayout)
              sidebarExpanded ? _expandedSidebar() : _collapsedSidebar(),
            Expanded(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _expandedSidebar({double width = 250}) {
    return Container(
      width: width,
      color: Colors.white,
      child: Column(
        children: [
          _logo(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WORKSPACE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF99999F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.workspaceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menus.length,
              itemBuilder: (context, index) =>
                  _menuItem(index, menus[index]),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFE9E9EC),
                  child: Icon(
                    Icons.person_outline,
                    size: 21,
                    color: Color(0xFF444449),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.adminEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF99999F),
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

  Widget _collapsedSidebar() {
    return Container(
      width: 72,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _logo(compact: true),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: menus.length,
              itemBuilder: (context, index) {
                final menu = menus[index];
                final selected = selectedMenu == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Tooltip(
                    message: menu.title,
                    child: Material(
                      color: selected
                          ? const Color(0xFFEAE9EE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleMenuTap(index),
                        child: SizedBox(
                          height: 50,
                          child: Icon(
                            selected ? menu.activeIcon : menu.icon,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Expand sidebar',
            onPressed: () => setState(() => sidebarExpanded = true),
            icon: const Icon(Icons.keyboard_double_arrow_right),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _logo({bool compact = false}) {
    return Container(
      height: 90,
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 22),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF242428),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 21,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            const Text(
              'HAREXAART',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuItem(int index, _Menu menu) {
    final selected = selectedMenu == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? const Color(0xFFEAE9EE) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleMenuTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? menu.activeIcon : menu.icon,
                  size: 20,
                ),
                const SizedBox(width: 13),
                Text(
                  menu.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuTap(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InputOrderPage(
            adminEmail: widget.adminEmail,
            workspaceId: widget.workspaceId,
            workspaceName: widget.workspaceName,
          ),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchOrderPage(
            adminEmail: widget.adminEmail,
            workspaceId: widget.workspaceId,
            workspaceName: widget.workspaceName,
          ),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditOrderPage(
            adminEmail: widget.adminEmail,
            workspaceId: widget.workspaceId,
            workspaceName: widget.workspaceName,
          ),
        ),
      );
      return;
    }

    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinancePage(
            adminEmail: widget.adminEmail,
            workspaceId: widget.workspaceId,
            workspaceName: widget.workspaceName,
          ),
        ),
      );
      return;
    }

    setState(() {
      selectedMenu = index;
    });
  }

  Widget _topBar() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactLayout = screenWidth < 1050;
    final verySmall = screenWidth < 420;

    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: compactLayout ? 10 : 24),
      color: Colors.white,
      child: Row(
        children: [
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: compactLayout
                  ? 'Buka menu'
                  : (sidebarExpanded ? 'Ciutkan sidebar' : 'Buka sidebar'),
              onPressed: () {
                if (compactLayout) {
                  Scaffold.of(buttonContext).openDrawer();
                } else {
                  setState(() {
                    sidebarExpanded = !sidebarExpanded;
                  });
                }
              },
              icon: Icon(
                compactLayout
                    ? Icons.menu
                    : (sidebarExpanded ? Icons.menu_open : Icons.menu),
              ),
            ),
          ),
          SizedBox(width: compactLayout ? 4 : 10),
          Expanded(
            child: Text(
              menus[selectedMenu].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: verySmall ? 8 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF3F7A4A),
                ),
                if (!verySmall) ...[
                  const SizedBox(width: 7),
                  const Text(
                    'ONLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: compactLayout ? 4 : 12),
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () {
              _message('Belum ada notifikasi baru.');
            },
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          if (!verySmall)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  Navigator.popUntil(
                    context,
                        (route) => route.isFirst,
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'profile',
                  child: Text('Profile'),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
              child: const CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFFEAEAED),
                child: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Color(0xFF424247),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(
            constraints.maxWidth < 600
                ? 14
                : constraints.maxWidth < 1050
                ? 20
                : 28,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: selectedMenu == 0
                ? _dashboard()
                : selectedMenu == 3
                ? _finance()
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _dashboard() {
    return AnimatedBuilder(
      animation: OrderStore.instance,
      builder: (context, _) {
        final orders = OrderStore.instance
            .getOrdersByWorkspace(widget.workspaceId)
            .toList();

        final today = _dateOnly(DateTime.now());
        final dailyRows = List.generate(_monitoringDays, (index) {
          final date = today.subtract(Duration(days: index));
          return _DailyOrderSummary(
            date: date,
            orders: orders.where((order) {
              final created = _dateOnly(order.createdAt);
              return created.year == date.year &&
                  created.month == date.month &&
                  created.day == date.day;
            }).toList(),
          );
        });

        final todaySummary = dailyRows.first;
        final recentOrders = orders.where((order) {
          final created = _dateOnly(order.createdAt);
          final oldest = today.subtract(Duration(days: _monitoringDays - 1));
          return !created.isBefore(oldest) && !created.isAfter(today);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final totalRecent = dailyRows.fold<int>(
          0,
              (sum, row) => sum + row.totalCount,
        );
        final processRecent = dailyRows.fold<int>(
          0,
              (sum, row) => sum + row.processCount,
        );
        final finishedRecent = dailyRows.fold<int>(
          0,
              (sum, row) => sum + row.finishedCount,
        );
        final recentValue = dailyRows.fold<int>(
          0,
              (sum, row) => sum + row.totalValue,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final compactHeader = headerConstraints.maxWidth < 850;
                final headerInfo = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoring Order',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pantau order ${widget.workspaceName} berdasarkan tanggal Input Order secara realtime.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF89898E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3F7A4A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'REALTIME',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: Color(0xFF3F7A4A),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tanggal aktif: ${_formatLongDate(today)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8E8E94),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (compactHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerInfo,
                      const SizedBox(height: 16),
                      _DashboardMiniChart(
                        rows: dailyRows,
                        days: _monitoringDays,
                        width: headerConstraints.maxWidth,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerInfo),
                    const SizedBox(width: 20),
                    _DashboardMiniChart(
                      rows: dailyRows,
                      days: _monitoringDays,
                      width: 330,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Monitoring dashboard sengaja dibatasi 7 hari agar tetap ringkas.
            // Arsip tanggal/bulan/tahun lengkap akan menjadi area pencarian terpisah.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE5E5E9)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_outlined,
                    size: 18,
                    color: Color(0xFF55555B),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Monitoring 7 Hari Terakhir',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      '7 HARI',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF6F6F75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // KPI monitoring.
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 1200
                    ? (constraints.maxWidth - 45) / 4
                    : constraints.maxWidth >= 800
                    ? (constraints.maxWidth - 15) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: [
                    _MonitoringKpiCard(
                      width: cardWidth,
                      title: 'Order Hari Ini',
                      value: '${todaySummary.totalCount}',
                      subtitle:
                      '${todaySummary.processCount} proses • ${todaySummary.finishedCount} selesai',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    _MonitoringKpiCard(
                      width: cardWidth,
                      title: 'Masih Diproses',
                      value: '$processRecent',
                      subtitle: 'Dalam periode ${_periodLabel(_monitoringDays)}',
                      icon: Icons.pending_actions_outlined,
                    ),
                    _MonitoringKpiCard(
                      width: cardWidth,
                      title: 'Sudah Selesai',
                      value: '$finishedRecent',
                      subtitle: 'Dalam periode ${_periodLabel(_monitoringDays)}',
                      icon: Icons.check_circle_outline,
                    ),
                    _MonitoringKpiCard(
                      width: cardWidth,
                      title: 'Nilai Order',
                      value: _formatFinanceRupiah(recentValue),
                      subtitle: '$totalRecent order dalam periode',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Tabel harian.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E5E9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, sectionConstraints) {
                      final compactSection = sectionConstraints.maxWidth < 620;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.calendar_month_outlined, size: 21),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Monitoring Harian',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (!compactSection) ...[
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    'Update otomatis • 00:00 ganti hari',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF929297),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (compactSection)
                            const Padding(
                              padding: EdgeInsets.only(left: 30, top: 3),
                              child: Text(
                                'Update otomatis • 00:00 ganti hari',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF929297),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, tableConstraints) {
                              final compactTable = tableConstraints.maxWidth < 700;
                              final table = Column(
                                children: [
                                  _DailyTableHeader(),
                                  const SizedBox(height: 7),
                                  ...dailyRows.map((row) => _DailyTableRow(row: row)),
                                ],
                              );

                              return compactTable
                                  ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(width: 680, child: table),
                              )
                                  : table;
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Detail order dengan thumbnail, ukuran, frame dan harga.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E5E9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 21),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Order Terbaru & Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '$totalRecent order',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF929297),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (recentOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 34),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 42,
                              color: Color(0xFFB9B9BE),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Belum ada order pada periode ini.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Order baru akan muncul otomatis sesuai tanggal Input Order.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF929297),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...recentOrders.map(
                          (order) => _DashboardOrderCard(order: order),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildGlobalDeleteManager(orders),

            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, panelConstraints) {
                final compactPanels = panelConstraints.maxWidth < 760;
                final panels = [
                  _panel(
                    'Status Sistem',
                    Icons.monitor_heart_outlined,
                    'Order Store READY • Realtime READY • Workspace ${widget.workspaceName}',
                  ),
                  _panel(
                    'Aturan Monitoring',
                    Icons.rule_outlined,
                    'Tanggal mengikuti createdAt/Input Order. Status proses mengikuti status order saat ini dan SELESAI dihitung dari status Keeper.',
                  ),
                ];

                if (compactPanels) {
                  return Column(
                    children: [
                      panels[0],
                      const SizedBox(height: 15),
                      panels[1],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: 20),
                    Expanded(child: panels[1]),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalDeleteManager(List<OrderData> orders) {
    final newOrders = orders
        .where((order) => order.keeperStage == KeeperStage.orderanMasuk)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final processingOrders = orders
        .where(
          (order) =>
      order.keeperStage == KeeperStage.sedangDikerjakan ||
          order.keeperStage == KeeperStage.inputResi,
    )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final finishedOrders = orders
        .where((order) => order.keeperStage == KeeperStage.selesaiDikerjakan)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final selectedCount = _selectedDeleteOrderIds.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;

              final title = Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola & Hapus Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Order aktif mengikuti data kartu produk dari workspace ini.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF929297),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actions = Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (!_deleteMode)
                    OutlinedButton.icon(
                      onPressed: orders.isEmpty
                          ? null
                          : () {
                        setState(() {
                          _deleteMode = true;
                          _selectedDeleteOrderIds.clear();
                        });
                      },
                      icon: const Icon(Icons.checklist_outlined, size: 16),
                      label: const Text('TANDA HAPUS'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: _deleteBusy
                          ? null
                          : () {
                        setState(() {
                          _selectedDeleteOrderIds
                            ..clear()
                            ..addAll(orders.map((order) => order.id));
                        });
                      },
                      child: const Text('PILIH SEMUA'),
                    ),
                    OutlinedButton(
                      onPressed: _deleteBusy || selectedCount == 0
                          ? null
                          : () => _confirmDeleteSelected(
                        selectedCount,
                      ),
                      child: Text('HAPUS TERPILIH ($selectedCount)'),
                    ),
                    TextButton(
                      onPressed: _deleteBusy
                          ? null
                          : () {
                        setState(() {
                          _deleteMode = false;
                          _selectedDeleteOrderIds.clear();
                        });
                      },
                      child: const Text('BATAL'),
                    ),
                  ],
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 13),
                    actions,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 15),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _buildDeleteProgressSection(
            title: 'ORDERAN BARU',
            subtitle: 'Order yang belum mulai dikerjakan.',
            orders: newOrders,
            icon: Icons.fiber_new_outlined,
            onDeleteAll: () => _confirmDeleteAllInSection(
              title: 'ORDERAN BARU',
              orders: newOrders,
            ),
          ),
          const SizedBox(height: 14),
          _buildDeleteProgressSection(
            title: 'SEDANG DIPROSES',
            subtitle: 'Order yang sedang dikerjakan atau masuk tahap resi.',
            orders: processingOrders,
            icon: Icons.timelapse_outlined,
            onDeleteAll: () => _confirmDeleteAllInSection(
              title: 'SEDANG DIPROSES',
              orders: processingOrders,
            ),
          ),
          const SizedBox(height: 14),
          _buildDeleteProgressSection(
            title: 'SELESAI',
            subtitle: 'Order yang sudah selesai di Keeper.',
            orders: finishedOrders,
            icon: Icons.check_circle_outline,
            onDeleteAll: () => _confirmDeleteAllInSection(
              title: 'SELESAI',
              orders: finishedOrders,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteProgressSection({
    required String title,
    required String subtitle,
    required List<OrderData> orders,
    required IconData icon,
    required VoidCallback onDeleteAll,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitle • ${orders.length} order',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF929297),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus semua $title',
                onPressed: _deleteBusy || orders.isEmpty ? null : onDeleteAll,
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
          if (orders.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...orders.map(
                  (order) => _DashboardOrderCard(
                order: order,
                deleteMode: _deleteMode,
                selected: _selectedDeleteOrderIds.contains(order.id),
                onSelect: (value) {
                  setState(() {
                    if (value) {
                      _selectedDeleteOrderIds.add(order.id);
                    } else {
                      _selectedDeleteOrderIds.remove(order.id);
                    }
                  });
                },
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Tidak ada order pada bagian ini.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF929297),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAllInSection({
    required String title,
    required List<OrderData> orders,
  }) async {
    if (orders.isEmpty || _deleteBusy) return;

    final confirmed = await _showDeleteDialog(
      count: orders.length,
      section: title,
    );

    if (!confirmed || !mounted) return;

    await _deleteOrders(
      orderIds: orders.map((order) => order.id).toList(),
      section: title,
    );
  }

  Future<void> _confirmDeleteSelected(int count) async {
    if (count == 0 || _deleteBusy) return;

    final confirmed = await _showDeleteDialog(
      count: count,
      section: 'ORDER TERPILIH',
    );

    if (!confirmed || !mounted) return;

    await _deleteOrders(
      orderIds: _selectedDeleteOrderIds.toList(),
      section: 'ORDER TERPILIH',
    );
  }

  Future<bool> _showDeleteDialog({
    required int count,
    required String section,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Order Permanen?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$count order dari $section akan dihapus permanen dari '
                '${widget.workspaceName} dan database. '
                'Order tidak akan muncul lagi di Admin, Keeper, Monitoring, '
                'atau Pencarian.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('BATAL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('HAPUS PERMANEN'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteOrders({
    required List<String> orderIds,
    required String section,
  }) async {
    if (orderIds.isEmpty || _deleteBusy) return;

    setState(() {
      _deleteBusy = true;
    });

    try {
      final deletedIds = await GlobalDeleteService.instance.deleteOrders(
        workspaceId: widget.workspaceId,
        orderIds: orderIds,
      );

      if (!mounted) return;

      setState(() {
        _selectedDeleteOrderIds.removeAll(deletedIds);
        _deleteBusy = false;
        if (_selectedDeleteOrderIds.isEmpty) {
          _deleteMode = false;
        }
      });

      _message(
        deletedIds.length == orderIds.length
            ? '${deletedIds.length} order dari $section berhasil dihapus permanen.'
            : '${deletedIds.length} dari ${orderIds.length} order berhasil dihapus.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _deleteBusy = false;
      });

      _message('Gagal menghapus order. Database menolak proses: $error');
    }
  }

  String _periodLabel(int days) {
    if (days == 1) return 'Hari Ini';
    if (days == 30) return '30 Hari';
    if (days == 90) return '90 Hari';
    return '$days Hari';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatLongDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatShortDate(DateTime date) {
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
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // KEUANGAN
  // DATA DIAMBIL LANGSUNG DARI ORDER STORE
  // WORKSPACE SELALU DIFILTER DENGAN workspaceId
  // ============================================================

  Widget _finance() {
    return AnimatedBuilder(
      animation: OrderStore.instance,
      builder: (context, _) {
        final orders = OrderStore.instance.getOrdersByWorkspace(
          widget.workspaceId,
        );

        final unfinishedOrders = orders
            .where((order) => order.status == OrderStatus.belumSelesai)
            .toList();

        final finishedOrders = orders
            .where((order) => order.status == OrderStatus.selesai)
            .toList();

        final unfinishedTotal = unfinishedOrders.fold<int>(
          0,
              (total, order) => total + order.price,
        );

        final finishedTotal = finishedOrders.fold<int>(
          0,
              (total, order) => total + order.price,
        );

        final allTotal = unfinishedTotal + finishedTotal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keuangan',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ringkasan nilai order ${widget.workspaceName}.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF89898E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data nominal mengikuti harga dari Input Order.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9A9AA0),
              ),
            ),
            const SizedBox(height: 28),

            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 1050
                    ? (constraints.maxWidth - 30) / 3
                    : constraints.maxWidth >= 700
                    ? (constraints.maxWidth - 15) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: [
                    _FinanceSummaryCard(
                      width: cardWidth,
                      title: 'Belum Selesai',
                      amount: _formatFinanceRupiah(unfinishedTotal),
                      count: '${unfinishedOrders.length} order',
                      icon: Icons.pending_actions_outlined,
                    ),
                    _FinanceSummaryCard(
                      width: cardWidth,
                      title: 'Selesai',
                      amount: _formatFinanceRupiah(finishedTotal),
                      count: '${finishedOrders.length} order',
                      icon: Icons.check_circle_outline,
                    ),
                    _FinanceSummaryCard(
                      width: cardWidth,
                      title: 'Total Semua Order',
                      amount: _formatFinanceRupiah(allTotal),
                      count: '${orders.length} order',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE5E5E9),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Detail Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${orders.length} order',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF929297),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Belum ada order pada workspace ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B8B90),
                          ),
                        ),
                      ),
                    )
                  else
                    ...orders.map(
                          (order) => _FinanceOrderRow(
                        order: order,
                        rupiah: _formatFinanceRupiah(order.price),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatFinanceRupiah(int value) {
    final text = value.toString();
    final reversed = text.split('').reversed.toList();
    final groups = <String>[];

    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length)
          ? i + 3
          : reversed.length;

      groups.add(
        reversed.sublist(i, end).reversed.join(),
      );
    }

    return 'Rp ${groups.reversed.join('.')}';
  }

  Widget _panel(
      String title,
      IconData icon,
      String text,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E5E9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8B8B90),
            ),
          ),
        ],
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DailyOrderSummary {
  final DateTime date;
  final List<OrderData> orders;

  const _DailyOrderSummary({
    required this.date,
    required this.orders,
  });

  int get totalCount => orders.length;

  int get finishedCount => orders
      .where((order) => order.status == OrderStatus.selesai)
      .length;

  int get processCount => totalCount - finishedCount;

  int get totalValue => orders.fold<int>(
    0,
        (sum, order) => sum + order.price,
  );

  List<OrderData> get previewOrders {
    final copy = List<OrderData>.from(orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.take(5).toList();
  }
}

class _MonitoringKpiCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MonitoringKpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF929297),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF929297),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'TANGGAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7D7D83),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ORDER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7D7D83),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PROSES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7D7D83),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'SELESAI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7D7D83),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'NILAI ORDER',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7D7D83),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'PREVIEW',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7D7D83),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTableRow extends StatelessWidget {
  final _DailyOrderSummary row;

  const _DailyTableRow({required this.row});

  String _weekday(DateTime date) {
    const names = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return names[date.weekday - 1];
  }

  String _rupiah(int value) {
    final text = value.toString();
    final reversed = text.split('').reversed.toList();
    final groups = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      groups.add(reversed.sublist(i, end).reversed.join());
    }
    return 'Rp ${groups.reversed.join('.')}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().year == row.date.year &&
        DateTime.now().month == row.date.month &&
        DateTime.now().day == row.date.day;

    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFAF8F0) : const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday ? const Color(0xFFE9DFC1) : const Color(0xFFEDEDF0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(right: 7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242428),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'HARI INI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        _weekday(row.date),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${row.date.day.toString().padLeft(2, '0')}/${row.date.month.toString().padLeft(2, '0')}/${row.date.year}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8E8E94),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '${row.totalCount}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _CountBadge(
                value: row.processCount,
                icon: Icons.timelapse_outlined,
                isFinished: false,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _CountBadge(
                value: row.finishedCount,
                icon: Icons.check_circle_outline,
                isFinished: true,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _rupiah(row.totalValue),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ...row.previewOrders.take(4).map(
                          (order) => Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: _OrderThumbnail(order: order, size: 34),
                      ),
                    ),
                    if (row.totalCount > 4)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '+${row.totalCount - 4}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF77777D),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int value;
  final IconData icon;
  final bool isFinished;

  const _CountBadge({
    required this.value,
    required this.icon,
    required this.isFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isFinished ? const Color(0xFFEAF5ED) : const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isFinished
                ? const Color(0xFF3F7A4A)
                : const Color(0xFF9A741A),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isFinished
                  ? const Color(0xFF3F7A4A)
                  : const Color(0xFF9A741A),
            ),
          ),
        ],
      ),
    );
  }
}


bool _adminIsPdf(Uint8List bytes) {
  if (bytes.length < 4) return false;
  final header = utf8.decode(
    bytes.take(8).toList(),
    allowMalformed: true,
  );
  return header.startsWith('%PDF-');
}

void _adminOpenReceipt(BuildContext context, OrderData order) {
  final bytes = order.shippingReceiptImage;
  final storageUrl = order.shippingReceiptUrl?.trim();

  // Prioritaskan bytes lokal. Jika tidak ada, gunakan URL Supabase Storage.
  if ((bytes == null || bytes.isEmpty) &&
      (storageUrl == null || storageUrl.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resi belum tersedia untuk order ini.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (bytes != null && bytes.isNotEmpty) {
    if (_adminIsPdf(bytes)) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      Future<void>.delayed(const Duration(minutes: 2), () {
        html.Url.revokeObjectUrl(url);
      });
      return;
    }
  } else if (storageUrl != null && storageUrl.isNotEmpty) {
    // Data yang di-hydrate dari Supabase dapat hanya memiliki URL Storage.
    // PDF tetap dibuka di tab baru; gambar ditampilkan sebagai preview.
    final cleanUrl = storageUrl.split('?').first.toLowerCase();
    if (cleanUrl.endsWith('.pdf')) {
      html.window.open(storageUrl, '_blank');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Resi • ${order.id}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.network(
                        storageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Gagal memuat resi.'),
                        ),
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
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Resi • ${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: Image.memory(bytes!, fit: BoxFit.contain),
                  ),
                ),
                if (order.shippingReceiptFileName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      order.shippingReceiptFileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777A82),
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

void _adminOpenProductImage(BuildContext context, OrderData order) {
  final bytes = order.productImage;
  final storageUrl = order.productImageUrl?.trim();
  if ((bytes == null || bytes.isEmpty) &&
      (storageUrl == null || storageUrl.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gambar order belum tersedia.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.image_outlined),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Gambar • ${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: bytes != null && bytes.isNotEmpty
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : Image.network(
                      storageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Gagal memuat gambar order.'),
                      ),
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

class _DashboardOrderCard extends StatelessWidget {
  final OrderData order;
  final bool deleteMode;
  final bool selected;
  final ValueChanged<bool>? onSelect;

  const _DashboardOrderCard({
    required this.order,
    this.deleteMode = false,
    this.selected = false,
    this.onSelect,
  });

  String _rupiah(int value) {
    final text = value.toString();
    final reversed = text.split('').reversed.toList();
    final groups = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      groups.add(reversed.sublist(i, end).reversed.join());
    }
    return 'Rp ${groups.reversed.join('.')}';
  }

  String _dateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final finished = order.status == OrderStatus.selesai;
    final statusText = finished ? 'SELESAI' : 'MASIH DIPROSES';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: deleteMode && selected
              ? const Color(0xFF9A741A)
              : const Color(0xFFEAEAEF),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: finished
                            ? const Color(0xFFE9F5EC)
                            : const Color(0xFFFFF5DF),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: finished
                              ? const Color(0xFF3F7A4A)
                              : const Color(0xFF9A741A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  order.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    _DetailPill(label: 'Ukuran: ${order.ukuran}'),
                    _DetailPill(label: 'Frame: ${order.frame}'),
                    _DetailPill(label: _rupiah(order.price)),
                    _DetailPill(label: 'Input: ${_dateTime(order.createdAt)}'),
                  ],
                ),
              ],
            ),
          );

          final thumb = _OrderThumbnail(order: order, size: 76);

          final reviewActions = Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              OutlinedButton.icon(
                onPressed: (order.productImage == null || order.productImage!.isEmpty) &&
                    (order.productImageUrl == null ||
                        order.productImageUrl!.trim().isEmpty)
                    ? null
                    : () => _adminOpenProductImage(context, order),
                icon: const Icon(Icons.image_outlined, size: 15),
                label: const Text('REVIEW GAMBAR'),
              ),
              OutlinedButton.icon(
                onPressed: (order.shippingReceiptImage == null ||
                    order.shippingReceiptImage!.isEmpty) &&
                    (order.shippingReceiptUrl == null ||
                        order.shippingReceiptUrl!.trim().isEmpty)
                    ? null
                    : () => _adminOpenReceipt(context, order),
                icon: const Icon(Icons.receipt_long_outlined, size: 15),
                label: Text(
                  ((order.shippingReceiptImage == null ||
                      order.shippingReceiptImage!.isEmpty) &&
                      (order.shippingReceiptUrl == null ||
                          order.shippingReceiptUrl!.trim().isEmpty))
                      ? 'RESI BELUM ADA'
                      : 'LIHAT RESI',
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
                    if (deleteMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Checkbox(
                          value: selected,
                          onChanged: onSelect == null
                              ? null
                              : (value) => onSelect!(value ?? false),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    thumb,
                    const SizedBox(width: 12),
                    info,
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: reviewActions,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (deleteMode)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Checkbox(
                    value: selected,
                    onChanged: onSelect == null
                        ? null
                        : (value) => onSelect!(value ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              thumb,
              const SizedBox(width: 14),
              Expanded(
                child: info,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _rupiah(order.price),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    finished ? 'Keeper selesai' : 'Masih dikerjakan',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8E8E94),
                    ),
                  ),
                  const SizedBox(height: 8),
                  reviewActions,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final String label;

  const _DetailPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6F6F75),
        ),
      ),
    );
  }
}

class _OrderThumbnail extends StatelessWidget {
  final OrderData order;
  final double size;

  const _OrderThumbnail({
    required this.order,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (order.productImage != null && order.productImage!.isNotEmpty) {
      child = Image.memory(
        order.productImage!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (order.productImageUrl != null &&
        order.productImageUrl!.trim().isNotEmpty) {
      child = Image.network(
        order.productImageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      child = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFEFEFF1),
        child: child,
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: size * .38,
        color: const Color(0xFFB0B0B5),
      ),
    );
  }
}

class _DashboardMiniChart extends StatelessWidget {
  final List<_DailyOrderSummary> rows;
  final int days;
  final double? width;

  const _DashboardMiniChart({
    required this.rows,
    required this.days,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final chartRows = rows.reversed.toList();

    return Container(
      width: width ?? 330,
      height: 148,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Trend Order',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                days == 1 ? 'Hari ini' : '${days} hari',
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF929297),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: const [
              _ChartLegendDot(
                color: Color(0xFF9A741A),
                label: 'Proses',
              ),
              SizedBox(width: 12),
              _ChartLegendDot(
                color: Color(0xFF3F7A4A),
                label: 'Selesai',
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: CustomPaint(
              painter: _MiniOrderChartPainter(rows: chartRows),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: Color(0xFF77777D),
          ),
        ),
      ],
    );
  }
}

class _MiniOrderChartPainter extends CustomPainter {
  final List<_DailyOrderSummary> rows;

  const _MiniOrderChartPainter({required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;

    final maxValue = rows.fold<int>(
      0,
          (max, row) => row.totalCount > max ? row.totalCount : max,
    ) +
        1;

    final chartWidth = size.width;
    final chartHeight = size.height - 14;
    final step = chartWidth / rows.length;
    final barWidth = rows.length <= 7
        ? 10.0
        : rows.length <= 14
        ? 7.0
        : 4.5;

    final gridPaint = Paint()
      ..color = const Color(0xFFEDEDF0)
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final y = chartHeight - (chartHeight / 2) * i;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final centerX = step * i + step / 2;
      final processHeight = chartHeight * row.processCount / maxValue;
      final finishedHeight = chartHeight * row.finishedCount / maxValue;

      final processPaint = Paint()..color = const Color(0xFF9A741A);
      final finishedPaint = Paint()..color = const Color(0xFF3F7A4A);

      final processRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth - 1,
          chartHeight - processHeight,
          barWidth,
          processHeight,
        ),
        const Radius.circular(3),
      );
      final finishedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX + 1,
          chartHeight - finishedHeight,
          barWidth,
          finishedHeight,
        ),
        const Radius.circular(3),
      );

      canvas.drawRRect(processRect, processPaint);
      canvas.drawRRect(finishedRect, finishedPaint);

      if (rows.length <= 14 || i == 0 || i == rows.length - 1) {
        final label = '${row.date.day}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 7,
              color: Color(0xFF8E8E94),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(centerX - textPainter.width / 2, chartHeight + 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniOrderChartPainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  final double width;
  final String title;
  final String amount;
  final String count;
  final IconData icon;

  const _FinanceSummaryCard({
    required this.width,
    required this.title,
    required this.amount,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE5E5E9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF929297),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF929297),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceOrderRow extends StatelessWidget {
  final OrderData order;
  final String rupiah;

  const _FinanceOrderRow({
    required this.order,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = order.status == OrderStatus.selesai;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFEAEAEF),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final status = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isFinished
                  ? const Color(0xFFE9F5EC)
                  : const Color(0xFFFFF5DF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isFinished ? 'SELESAI' : 'BELUM SELESAI',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isFinished
                    ? const Color(0xFF3F7A4A)
                    : const Color(0xFF9A741A),
              ),
            ),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${order.productName}  •  ${order.ukuran}  •  ${order.frame}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF77777D),
                ),
              ),
            ],
          );

          final money = Text(
            rupiah,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 12),
                Row(
                  children: [
                    money,
                    const Spacer(),
                    status,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 18),
              money,
              const SizedBox(width: 16),
              status,
            ],
          );
        },
      ),
    );
  }
}

class _Menu {
  final String title;
  final IconData icon;
  final IconData activeIcon;

  const _Menu(
      this.title,
      this.icon,
      this.activeIcon,
      );
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _Stat(
      this.title,
      this.value,
      this.icon,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE5E5E9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF929297),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
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
}
