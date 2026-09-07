import 'package:flutter/material.dart';

import '../../../data/order_store.dart';
import 'payment_model.dart';
import 'payment_pdf_service.dart';
import 'payment_store.dart';

/// ============================================================================
/// HAREXAART - PAYMENT PAGE
/// ============================================================================
///
/// Halaman pembayaran Finance.
///
/// ALUR DATA:
/// INPUT ORDER
///      ↓
/// ORDER STORE
///      ↓
/// KEEPER SELESAI
///      ↓
/// ADMIN BAYAR
///      ↓
/// PAYMENT STORE
///      ↓
/// RIWAYAT PEMBAYARAN
///
/// ATURAN:
/// - Nominal tidak boleh diketik manual.
/// - Nominal selalu mengambil OrderData.price.
/// - Hanya order SELESAI yang boleh masuk pembayaran.
/// - Hanya order BELUM DIBAYAR yang boleh dibayar.
/// - Workspace harus sama persis.
/// - completedAt berasal dari Keeper.
/// - paidAt dibuat ketika Admin melakukan finalisasi.
/// - createdAt tidak pernah diubah oleh pembayaran.
/// - PaymentStore hanya menyimpan audit pembayaran.
/// - OrderStore tetap menjadi sumber kebenaran order produksi.
/// ============================================================================

class PaymentPage extends StatefulWidget {
  final String adminEmail;
  final String workspaceId;
  final String workspaceName;

  const PaymentPage({
    super.key,
    required this.adminEmail,
    required this.workspaceId,
    required this.workspaceName,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isProcessingPayment = false;

  // Seleksi pembayaran. ID disimpan agar aman walaupun list berubah saat realtime.
  final Set<String> _selectedUnpaidOrderIds = <String>{};
  final Set<String> _selectedPaidPaymentIds = <String>{};

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    OrderStore.instance.addListener(_onOrderStoreChanged);
    PaymentStore.instance.addListener(_onPaymentStoreChanged);

    // Jika sudah ada pembayaran yang tersimpan di OrderStore,
    // masukkan ke PaymentStore sebagai audit record.
    PaymentStore.instance.syncPaidOrdersFromOrderStore(widget.workspaceId);
  }

  @override
  void dispose() {
    OrderStore.instance.removeListener(_onOrderStoreChanged);
    PaymentStore.instance.removeListener(_onPaymentStoreChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onOrderStoreChanged() {
    if (!mounted) {
      return;
    }

    // Sinkronisasi hanya untuk pembayaran yang memang sudah finalized.
    PaymentStore.instance.syncPaidOrdersFromOrderStore(widget.workspaceId);

    _selectedUnpaidOrderIds.removeWhere(
          (id) => !_unpaidRecords.any((payment) => payment.orderId == id),
    );
    _selectedPaidPaymentIds.removeWhere(
          (id) => !_paidRecords.any((payment) => payment.paymentId == id),
    );

    setState(() {});
  }

  void _onPaymentStoreChanged() {
    if (!mounted) {
      return;
    }

    _selectedPaidPaymentIds.removeWhere(
          (id) => !_paidRecords.any((payment) => payment.paymentId == id),
    );

    setState(() {});
  }

  String get _workspaceDisplayName {
    if (widget.workspaceName.trim().isNotEmpty) {
      return widget.workspaceName;
    }

    if (widget.workspaceId == 'harexaart') {
      return 'HarexaArt';
    }

    if (widget.workspaceId == 'lavanya_art') {
      return 'Lavanya Art';
    }

    return widget.workspaceName;
  }

  /// Semua order workspace.
  List<PaymentRecord> get _records {
    final orders = OrderStore.instance.getOrdersByWorkspace(
      widget.workspaceId,
    );

    final records = orders
        .map(PaymentRecord.fromOrder)
        .where(
          (payment) => payment.workspaceId == widget.workspaceId,
    )
        .toList();

    records.sort((a, b) {
      return b.orderCreatedAt.compareTo(a.orderCreatedAt);
    });

    return records;
  }

  /// Order yang benar-benar selesai dan belum dibayar.
  List<PaymentRecord> get _unpaidRecords {
    return _records
        .where(
          (payment) =>
      payment.isCompleted &&
          payment.isUnpaid &&
          payment.isValidForWorkspace(widget.workspaceId) &&
          payment.completedAt != null &&
          payment.paidAt == null &&
          payment.amount > 0,
    )
        .toList();
  }

  /// Riwayat pembayaran berasal dari PaymentStore.
  List<PaymentRecord> get _paidRecords {
    final records = PaymentStore.instance
        .getPaidPaymentsByWorkspace(widget.workspaceId)
        .where(
          (payment) =>
      payment.workspaceId == widget.workspaceId &&
          payment.isCompleted &&
          payment.isPaid &&
          payment.paidAt != null,
    )
        .toList();

    records.sort((a, b) {
      final aDate = a.paidAt ?? a.orderCreatedAt;
      final bDate = b.paidAt ?? b.orderCreatedAt;
      return bDate.compareTo(aDate);
    });

    return records;
  }

  List<PaymentRecord> get _selectedUnpaidRecords {
    return _unpaidRecords
        .where((payment) => _selectedUnpaidOrderIds.contains(payment.orderId))
        .where((payment) => payment.isValidForPayment(widget.workspaceId))
        .toList();
  }

  List<PaymentRecord> get _selectedPaidRecords {
    return _paidRecords
        .where((payment) => _selectedPaidPaymentIds.contains(payment.paymentId))
        .where((payment) => payment.workspaceId == widget.workspaceId)
        .toList();
  }

  int get _selectedUnpaidTotal => _selectedUnpaidRecords.fold(
    0,
        (total, item) => total + item.amount,
  );

  int get _selectedPaidTotal => _selectedPaidRecords.fold(
    0,
        (total, item) => total + item.amount,
  );

  bool get _allUnpaidSelected =>
      _unpaidRecords.isNotEmpty &&
          _unpaidRecords.every(
                (payment) => _selectedUnpaidOrderIds.contains(payment.orderId),
          );

  bool get _allPaidSelected =>
      _paidRecords.isNotEmpty &&
          _paidRecords.every(
                (payment) => _selectedPaidPaymentIds.contains(payment.paymentId),
          );

  void _toggleUnpaidSelection(PaymentRecord payment) {
    if (!payment.isEligibleForPayment) {
      return;
    }

    setState(() {
      if (_selectedUnpaidOrderIds.contains(payment.orderId)) {
        _selectedUnpaidOrderIds.remove(payment.orderId);
      } else {
        _selectedUnpaidOrderIds.add(payment.orderId);
      }
    });
  }

  void _togglePaidSelection(PaymentRecord payment) {
    setState(() {
      if (_selectedPaidPaymentIds.contains(payment.paymentId)) {
        _selectedPaidPaymentIds.remove(payment.paymentId);
      } else {
        _selectedPaidPaymentIds.add(payment.paymentId);
      }
    });
  }

  void _toggleSelectAllUnpaid() {
    setState(() {
      if (_allUnpaidSelected) {
        _selectedUnpaidOrderIds.clear();
      } else {
        _selectedUnpaidOrderIds
          ..clear()
          ..addAll(
            _unpaidRecords
                .where((payment) => payment.isEligibleForPayment)
                .map((payment) => payment.orderId),
          );
      }
    });
  }

  void _toggleSelectAllPaid() {
    setState(() {
      if (_allPaidSelected) {
        _selectedPaidPaymentIds.clear();
      } else {
        _selectedPaidPaymentIds
          ..clear()
          ..addAll(_paidRecords.map((payment) => payment.paymentId));
      }
    });
  }

  int get _unpaidTotal {
    return _unpaidRecords.fold(
      0,
          (total, item) => total + item.amount,
    );
  }

  int get _paidTotal {
    return _paidRecords.fold(
      0,
          (total, item) => total + item.amount,
    );
  }

  int get _completedTotal {
    return _records
        .where(
          (item) =>
      item.isCompleted &&
          item.isValidForWorkspace(widget.workspaceId),
    )
        .fold(
      0,
          (total, item) => total + item.amount,
    );
  }

  int get _completedCount {
    return _records
        .where(
          (item) =>
      item.isCompleted &&
          item.isValidForWorkspace(widget.workspaceId),
    )
        .length;
  }

  String _formatRupiah(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }

    return 'Rp ${buffer.toString()}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  Future<void> _showSelectedPdf({required bool paid}) async {
    final records = paid ? _selectedPaidRecords : _selectedUnpaidRecords;

    if (records.isEmpty) {
      _showMessage(
        'Pilih minimal 1 pembayaran terlebih dahulu.',
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1100,
              maxHeight: 850,
            ),
            child: Column(
              children: [
                _buildPdfDialogHeader(
                  title: paid ? 'PDF Riwayat Pembayaran' : 'PDF Pembayaran Terpilih',
                  subtitle: '${records.length} order • ${_formatRupiah(records.fold<int>(0, (total, item) => total + item.amount))}',
                ),
                Expanded(
                  child: PaymentPdfService().buildPdfPreview(
                    records: records,
                    workspaceId: widget.workspaceId,
                    workspaceName: _workspaceDisplayName,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E6E9)),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('TUTUP'),
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

  Widget _buildPdfDialogHeader({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E6E9)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8D4),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFF8A6A27),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_workspaceDisplayName} • $subtitle',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF85878C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectedPaymentConfirmation() async {
    if (_isProcessingPayment) {
      return;
    }

    final selected = _selectedUnpaidRecords;

    if (selected.isEmpty) {
      _showMessage(
        'Pilih minimal 1 order yang memenuhi syarat pembayaran.',
        isError: true,
      );
      return;
    }

    final total = selected.fold<int>(
      0,
          (sum, payment) => sum + payment.amount,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Bayar ${selected.length} Order Sekaligus',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semua order yang dipilih akan difinalisasi sebagai SUDAH DIBAYAR.',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 15),
                Container(
                  constraints: const BoxConstraints(maxHeight: 230),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: selected.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final payment = selected[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                        title: Text(
                          payment.orderId,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        subtitle: Text(
                          '${payment.ukuran} • ${payment.frame}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: Text(
                          _formatRupiah(payment.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TOTAL PEMBAYARAN',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                    Text(
                      _formatRupiah(total),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nominal setiap order tetap berasal dari harga final Input Order dan tidak dapat diedit.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
              label: const Text('PREVIEW PDF & LANJUT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222326),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _showSelectedPaymentPdfReview(selected);
  }

  Future<void> _showSelectedPaymentPdfReview(
      List<PaymentRecord> selected,
      ) async {
    final valid = selected
        .where((payment) => payment.isValidForPayment(widget.workspaceId))
        .toList();

    if (valid.length != selected.length || valid.isEmpty) {
      _showMessage(
        'Ada order yang berubah status. Silakan pilih ulang pembayaran.',
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
            child: Column(
              children: [
                _buildPdfDialogHeader(
                  title: 'Preview Pembayaran ${valid.length} Order',
                  subtitle: '${valid.length} halaman/order • belum difinalisasi',
                ),
                Expanded(
                  child: PaymentPdfService().buildPdfPreview(
                    records: valid,
                    workspaceId: widget.workspaceId,
                    workspaceName: _workspaceDisplayName,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E6E9))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('BATAL'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _processSelectedPayments(valid);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        label: const Text('FINALISASI & BAYAR SEMUA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF222326),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processSelectedPayments(
      List<PaymentRecord> selected,
      ) async {
    if (_isProcessingPayment || selected.isEmpty) {
      return;
    }

    // Revalidasi seluruh order sebelum satu pun pembayaran dilakukan.
    final latestRecords = _unpaidRecords
        .where((payment) => selected.any((item) => item.orderId == payment.orderId))
        .toList();

    if (latestRecords.length != selected.length ||
        latestRecords.any((payment) => !payment.isValidForPayment(widget.workspaceId))) {
      _showMessage(
        'Pembayaran dibatalkan karena data order berubah. Silakan pilih ulang.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    final paymentDate = DateTime.now();
    var successCount = 0;

    try {
      for (final payment in latestRecords) {
        final success = OrderStore.instance.markAsPaid(
          orderId: payment.orderId,
          workspaceId: widget.workspaceId,
          paymentDate: paymentDate,
        );

        if (!success) {
          throw StateError('Gagal memfinalisasi ${payment.orderId}.');
        }

        successCount++;
      }

      _selectedUnpaidOrderIds.clear();

      if (!mounted) {
        return;
      }

      final finalized = _records
          .where((payment) => latestRecords.any((item) => item.orderId == payment.orderId))
          .where((payment) => payment.isPaid && payment.paidAt != null)
          .toList();

      for (final payment in finalized) {
        final order = OrderStore.instance.getOrderById(payment.orderId);
        if (order != null) {
          PaymentStore.instance.addPaymentFromOrder(order);
        }
      }

      await _showBulkPaymentSuccess(finalized);
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Sebagian/seluruh pembayaran gagal diproses: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }

    if (successCount != selected.length && mounted) {
      _showMessage(
        '$successCount dari ${selected.length} order berhasil dibayar.',
        isError: true,
      );
    }
  }

  Future<void> _showBulkPaymentSuccess(
      List<PaymentRecord> finalized,
      ) async {
    if (!mounted || finalized.isEmpty) {
      return;
    }

    final total = finalized.fold<int>(
      0,
          (sum, item) => sum + item.amount,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF3F7A4A)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Pembayaran Berhasil',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            '${finalized.length} order berhasil difinalisasi sebagai SUDAH DIBAYAR.\n\n'
                'Total: ${_formatRupiah(total)}\n\n'
                'Semua order dibuat menjadi satu laporan PDF multi-halaman.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _showFinalizedPdfRecords(finalized);
              },
              child: const Text('LIHAT PDF'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('SELESAI'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFinalizedPdfRecords(
      List<PaymentRecord> records,
      ) async {
    if (records.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
            child: Column(
              children: [
                _buildPdfDialogHeader(
                  title: 'PDF Final Pembayaran',
                  subtitle: '${records.length} order • satu file multi-halaman',
                ),
                Expanded(
                  child: PaymentPdfService().buildPdfPreview(
                    records: records,
                    workspaceId: widget.workspaceId,
                    workspaceName: _workspaceDisplayName,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E6E9))),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('TUTUP'),
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

  Future<void> _showPaymentConfirmation(
      PaymentRecord payment,
      ) async {
    if (_isProcessingPayment) {
      return;
    }

    if (!payment.isValidForPayment(widget.workspaceId)) {
      _showMessage(
        'Order ini belum memenuhi syarat pembayaran.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Konfirmasi Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.orderId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 15),
                _dialogInfoRow('Produk', payment.productName),
                const SizedBox(height: 6),
                _dialogInfoRow('Ukuran', payment.ukuran),
                const SizedBox(height: 6),
                _dialogInfoRow('Frame', payment.frame),
                const SizedBox(height: 6),
                _dialogInfoRow('Workspace', payment.workspaceName),
                const SizedBox(height: 15),
                _dialogInfoRow(
                  'Input Order',
                  _formatDate(payment.orderCreatedAt),
                ),
                const SizedBox(height: 6),
                _dialogInfoRow(
                  'Keeper Selesai',
                  _formatDate(payment.completedAt),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nominal pembayaran:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatRupiah(payment.amount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 17,
                        color: Color(0xFF8A6A27),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Nominal diambil otomatis dari harga final Input Order. Admin tidak dapat mengubah nominal dari halaman pembayaran.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: Color(0xFF6F6A5E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Setelah dikonfirmasi, order akan ditandai sebagai SUDAH DIBAYAR dan timestamp Admin akan dicatat.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('BATAL'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(
                Icons.check_circle_outline,
                size: 17,
              ),
              label: const Text('KONFIRMASI BAYAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222326),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _showPaymentPdfReview(payment);
  }

  Future<void> _showPaymentPdfReview(PaymentRecord payment) async {
    if (_isProcessingPayment) {
      return;
    }

    if (!payment.isValidForPayment(widget.workspaceId)) {
      _showMessage(
        'Order ini tidak lagi memenuhi syarat pembayaran.',
        isError: true,
      );
      return;
    }

    final DateTime paymentDate = DateTime.now();

    // Preview menggunakan record asli yang masih BELUM DIBAYAR.
    // OrderStore baru berubah setelah Admin menekan FINALISASI & BAYAR.
    final PaymentRecord previewRecord = payment;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1100,
              maxHeight: 850,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE5E6E9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E8D4),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Color(0xFF8A6A27),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview Laporan Pembayaran',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Periksa dokumen sebelum finalisasi pembayaran.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF85878C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PaymentPdfService().buildPdfPreview(
                    records: [previewRecord],
                    workspaceId: widget.workspaceId,
                    workspaceName: _workspaceDisplayName,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFB),
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE5E6E9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Status order belum diubah. Pembayaran baru difinalisasi setelah tombol ini ditekan.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF77797E),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('BATAL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _processPayment(
                            payment,
                            paymentDate: paymentDate,
                          );
                        },
                        icon: const Icon(
                          Icons.verified_outlined,
                          size: 17,
                        ),
                        label: const Text('FINALISASI & BAYAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF222326),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processPayment(
      PaymentRecord payment, {
        DateTime? paymentDate,
      }) async {
    if (_isProcessingPayment) {
      return;
    }

    if (!payment.isValidForPayment(widget.workspaceId)) {
      _showMessage(
        'Pembayaran tidak dapat diproses karena validasi gagal.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Final validation langsung terhadap OrderStore.
      final success = OrderStore.instance.markAsPaid(
        orderId: payment.orderId,
        workspaceId: widget.workspaceId,
        paymentDate: paymentDate ?? DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          'Pembayaran gagal. Order mungkin sudah dibayar atau tidak memenuhi validasi.',
          isError: true,
        );
        return;
      }

      // Ambil data terbaru setelah OrderStore berhasil diubah.
      final updatedOrder = OrderStore.instance.getOrderById(
        payment.orderId,
      );

      if (updatedOrder == null) {
        _showMessage(
          'Pembayaran berhasil, tetapi data order terbaru tidak ditemukan.',
          isError: true,
        );
        return;
      }

      // PaymentStore hanya menerima order yang sudah benar-benar paid.
      final auditSaved = PaymentStore.instance.addPaymentFromOrder(
        updatedOrder,
      );

      if (!auditSaved) {
        // Jangan membatalkan pembayaran OrderStore karena sumber kebenaran
        // tetap OrderStore. Sinkronisasi berikutnya akan mencoba lagi.
        _showMessage(
          'Pembayaran berhasil. Audit PaymentStore akan disinkronkan otomatis.',
        );
      }

      _showPaymentSuccess(updatedOrder);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  Future<void> _showFinalizedPdf(OrderData order) async {
    final PaymentRecord record = PaymentRecord.fromOrder(order);

    if (!record.isPaid || record.paidAt == null) {
      _showMessage(
        'PDF hanya dapat dibuka untuk pembayaran yang sudah difinalisasi.',
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1100,
              maxHeight: 850,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE5E6E9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Color(0xFF8A6A27),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Laporan Pembayaran Final',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PaymentPdfService().buildPdfPreview(
                    records: [record],
                    workspaceId: widget.workspaceId,
                    workspaceName: _workspaceDisplayName,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentSuccess(OrderData order) {
    final payment = PaymentRecord.fromOrder(order);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFF39744A),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Pembayaran Berhasil',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.orderId,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${payment.productName} berhasil difinalisasi.',
              ),
              const SizedBox(height: 8),
              Text(
                _formatRupiah(payment.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Admin Bayar: ${_formatDate(payment.paidAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Record pembayaran sudah masuk ke PaymentStore sebagai audit pembayaran.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showFinalizedPdf(order);
              },
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 16,
              ),
              label: const Text('LIHAT PDF'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222326),
                foregroundColor: Colors.white,
              ),
              child: const Text('SELESAI'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogInfoRow(
      String label,
      String value,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCleanupInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Pembayaran Minggu Ini',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Cleanup pembayaran akan menghapus record audit di PaymentStore, bukan OrderData atau riwayat produksi.\n\n'
                'Untuk sementara tombol ini belum melakukan penghapusan karena sistem PDF final belum terhubung. Setelah PDF final aktif, cleanup akan dijalankan setelah pembayaran dan dokumen selesai difinalisasi.',
            style: TextStyle(
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('MENGERTI'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSummary(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPaymentList(
                    records: _unpaidRecords,
                    unpaid: true,
                  ),
                  _buildPaymentList(
                    records: _paidRecords,
                    unpaid: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E6E9),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8D4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF8A6A27),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pembayaran',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _workspaceDisplayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF85878C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.adminEmail.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Color(0xFF62646A),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 180,
                    ),
                    child: Text(
                      widget.adminEmail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF55575C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _showCleanupInfo,
            icon: const Icon(
              Icons.cleaning_services_outlined,
              size: 17,
            ),
            label: const Text(
              'Hapus Pembayaran Minggu Ini',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF44464B),
              side: const BorderSide(
                color: Color(0xFFD8D9DC),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 11,
              ),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 1000
              ? (constraints.maxWidth - 32) / 3
              : constraints.maxWidth >= 650
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _summaryCard(
                width: width,
                title: 'Menunggu Pembayaran',
                value: _formatRupiah(_unpaidTotal),
                count: '${_unpaidRecords.length} order',
                icon: Icons.pending_actions_outlined,
              ),
              _summaryCard(
                width: width,
                title: 'Sudah Dibayar',
                value: _formatRupiah(_paidTotal),
                count: '${_paidRecords.length} order',
                icon: Icons.check_circle_outline,
              ),
              _summaryCard(
                width: width,
                title: 'Total Order Selesai',
                value: _formatRupiah(_completedTotal),
                count: '$_completedCount order',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required double width,
    required String title,
    required String value,
    required String count,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E6E9),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF8A6A27),
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7E8085),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF96989D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFE5E6E9),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF222326),
        unselectedLabelColor: const Color(0xFF8D8F94),
        indicatorColor: const Color(0xFF9B782F),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            text: 'Menunggu Pembayaran (${_unpaidRecords.length})',
          ),
          Tab(
            text: 'Sudah Dibayar (${_paidRecords.length})',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList({
    required List<PaymentRecord> records,
    required bool unpaid,
  }) {
    if (records.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                unpaid
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
                size: 52,
                color: const Color(0xFFB9BABE),
              ),
              const SizedBox(height: 14),
              Text(
                unpaid
                    ? 'Belum ada order yang menunggu pembayaran.'
                    : 'Belum ada riwayat pembayaran.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                unpaid
                    ? 'Order akan muncul setelah Keeper menekan SELESAI REAL.'
                    : 'Pembayaran yang sudah difinalisasi akan tampil di sini.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B8D92),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSelectionToolbar(
          records: records,
          unpaid: unpaid,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              22,
              10,
              22,
              30,
            ),
            itemCount: records.length,
            separatorBuilder: (_, __) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              return _paymentCard(
                records[index],
                unpaid: unpaid,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionToolbar({
    required List<PaymentRecord> records,
    required bool unpaid,
  }) {
    final selectedCount = unpaid
        ? _selectedUnpaidRecords.length
        : _selectedPaidRecords.length;
    final selectedTotal = unpaid
        ? _selectedUnpaidTotal
        : _selectedPaidTotal;
    final allSelected = unpaid ? _allUnpaidSelected : _allPaidSelected;

    return Container(
      margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5E6E9)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Checkbox(
            value: allSelected,
            tristate: selectedCount > 0 && !allSelected,
            onChanged: (_) {
              if (unpaid) {
                _toggleSelectAllUnpaid();
              } else {
                _toggleSelectAllPaid();
              }
            },
          ),
          Text(
            allSelected ? 'SEMUA TERPILIH' : 'PILIH SEMUA',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$selectedCount dipilih',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          if (selectedCount > 0)
            Text(
              _formatRupiah(selectedTotal),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: selectedCount == 0
                ? null
                : () => _showSelectedPdf(paid: !unpaid),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('PDF TERPILIH'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          if (unpaid)
            ElevatedButton.icon(
              onPressed: selectedCount == 0 || _isProcessingPayment
                  ? null
                  : _showSelectedPaymentConfirmation,
              icon: _isProcessingPayment
                  ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.payments_outlined, size: 16),
              label: Text(
                _isProcessingPayment
                    ? 'MEMPROSES...'
                    : 'BAYAR TERPILIH',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222326),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentCard(
      PaymentRecord payment, {
        required bool unpaid,
      }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE5E6E9),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectionCheckRow(payment, unpaid: unpaid),
                const SizedBox(height: 10),
                _buildProductImage(payment),
                const SizedBox(height: 15),
                _buildPaymentInformation(
                  payment,
                  unpaid: unpaid,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSelectionCheck(payment, unpaid: unpaid),
              const SizedBox(width: 8),
              _buildProductImage(payment),
              const SizedBox(width: 17),
              Expanded(
                child: _buildPaymentInformation(
                  payment,
                  unpaid: unpaid,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectionCheckRow(
      PaymentRecord payment, {
        required bool unpaid,
      }) {
    final selected = unpaid
        ? _selectedUnpaidOrderIds.contains(payment.orderId)
        : _selectedPaidPaymentIds.contains(payment.paymentId);
    final enabled = unpaid ? payment.isEligibleForPayment : payment.isPaid;

    return Row(
      children: [
        _buildSelectionCheck(payment, unpaid: unpaid),
        Expanded(
          child: Text(
            selected ? 'TERPILIH' : (enabled ? 'PILIH ORDER' : 'TIDAK TERSEDIA'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF8A6A27) : const Color(0xFF8B8D92),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCheck(
      PaymentRecord payment, {
        required bool unpaid,
      }) {
    final selected = unpaid
        ? _selectedUnpaidOrderIds.contains(payment.orderId)
        : _selectedPaidPaymentIds.contains(payment.paymentId);
    final enabled = unpaid ? payment.isEligibleForPayment : payment.isPaid;

    return Checkbox(
      value: selected,
      onChanged: !enabled
          ? null
          : (_) {
        if (unpaid) {
          _toggleUnpaidSelection(payment);
        } else {
          _togglePaidSelection(payment);
        }
      },
    );
  }

  Widget _buildProductImage(
      PaymentRecord payment,
      ) {
    Widget image;

    // Prioritas pertama: gambar yang masih tersedia sebagai bytes.
    if (payment.productImage != null &&
        payment.productImage!.isNotEmpty) {
      image = Image.memory(
        payment.productImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _imagePlaceholder();
        },
      );
    } else if (payment.productImageUrl != null &&
        payment.productImageUrl!.trim().isNotEmpty) {
      // Fallback untuk URL Storage/Supabase.
      image = Image.network(
        payment.productImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _imagePlaceholder();
        },
      );
    } else {
      image = _imagePlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 105,
        height: 105,
        child: image,
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F2F4),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xFF9B9DA2),
          size: 30,
        ),
      ),
    );
  }

  Widget _buildPaymentInformation(
      PaymentRecord payment, {
        required bool unpaid,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                payment.orderId,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _statusBadge(
              payment.isPaid
                  ? 'SUDAH DIBAYAR'
                  : 'BELUM DIBAYAR',
              paid: payment.isPaid,
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          payment.productName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _infoChip(
              Icons.straighten_outlined,
              payment.ukuran,
            ),
            _infoChip(
              Icons.crop_square_outlined,
              payment.frame,
            ),
            _infoChip(
              Icons.storefront_outlined,
              payment.workspaceName,
            ),
          ],
        ),
        const SizedBox(height: 15),
        _dateRow(
          label: 'Input Order',
          date: payment.orderCreatedAt,
        ),
        const SizedBox(height: 6),
        _dateRow(
          label: 'Keeper Selesai',
          date: payment.completedAt,
        ),
        if (payment.isPaid) ...[
          const SizedBox(height: 6),
          _dateRow(
            label: 'Admin Bayar',
            date: payment.paidAt,
          ),
        ],
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5ED),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Nominal Final',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF77736A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatRupiah(payment.amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (unpaid) ...[
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              _isProcessingPayment ||
                  !payment.isEligibleForPayment
                  ? null
                  : () {
                _showPaymentConfirmation(payment);
              },
              icon: _isProcessingPayment
                  ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.payments_outlined,
                size: 18,
              ),
              label: Text(
                _isProcessingPayment
                    ? 'MEMPROSES...'
                    : 'BAYAR',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                backgroundColor: const Color(0xFF222326),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                const Color(0xFFE1E2E5),
                disabledForegroundColor:
                const Color(0xFF92949A),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(
      String text, {
        required bool paid,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: paid
            ? const Color(0xFFEAF4ED)
            : const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: paid
              ? const Color(0xFF39744A)
              : const Color(0xFF946E1E),
        ),
      ),
    );
  }

  Widget _infoChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: const Color(0xFF7C7E84),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF62646A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime? date,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8C8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E5055),
            ),
          ),
        ),
      ],
    );
  }
}

