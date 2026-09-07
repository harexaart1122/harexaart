// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../data/order_store.dart';
import 'edit_order_page.dart';

class SearchOrderPage extends StatefulWidget {
  final String adminEmail;
  final String workspaceId;
  final String workspaceName;

  const SearchOrderPage({
    super.key,
    required this.adminEmail,
    required this.workspaceId,
    required this.workspaceName,
  });

  @override
  State<SearchOrderPage> createState() => _SearchOrderPageState();
}

class _SearchOrderPageState extends State<SearchOrderPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _receiptTextCache = <String, String>{};
  final Set<String> _receiptIndexing = <String>{};
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    OrderStore.instance.addListener(_handleStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _indexPdfReceipts();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    OrderStore.instance.removeListener(_handleStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) return;
    _indexPdfReceipts();
    setState(() {});
  }

  void _handleSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _query = _searchController.text.trim();
      });
      _indexPdfReceipts(force: _looksLikeReceiptNumber(_query));
    });
  }

  bool _looksLikeReceiptNumber(String query) {
    final compact = query.replaceAll(RegExp(r'[^0-9]'), '');
    return compact.length >= 5 && compact.length >= query.replaceAll(RegExp(r'\s'), '').length * .6;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _normalizeLoose(String value) {
    return value
        .toLowerCase()
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _indexPdfReceipts({bool force = false}) async {
    final orders = OrderStore.instance
        .getOrdersByWorkspace(widget.workspaceId)
        .where(
          (o) =>
      (o.shippingReceiptImage != null &&
          o.shippingReceiptImage!.isNotEmpty) ||
          (o.shippingReceiptUrl?.trim().isNotEmpty ?? false),
    )
        .toList();

    for (final order in orders) {
      if (_receiptIndexing.contains(order.id)) continue;
      if (!force && _receiptTextCache.containsKey(order.id)) continue;

      _receiptIndexing.add(order.id);
      try {
        Uint8List? bytes = order.shippingReceiptImage;

        if ((bytes == null || bytes.isEmpty) &&
            (order.shippingReceiptUrl?.trim().isNotEmpty ?? false)) {
          bytes = await _fetchStorageBytes(order.shippingReceiptUrl!.trim());
        }

        if (bytes == null || bytes.isEmpty || !_isPdfBytes(bytes)) {
          _receiptTextCache[order.id] = '';
          continue;
        }

        final text = await _extractPdfText(bytes);
        _receiptTextCache[order.id] = text.trim();
      } catch (_) {
        _receiptTextCache[order.id] = '';
      } finally {
        _receiptIndexing.remove(order.id);
      }
    }

    if (mounted) setState(() {});
  }

  Future<String> _extractPdfText(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  Future<Uint8List?> _fetchStorageBytes(String url) async {
    try {
      final response = await html.HttpRequest.request(
        url,
        method: 'GET',
        responseType: 'arraybuffer',
      );
      if (response.status != 200 || response.response == null) return null;
      return Uint8List.view(response.response as ByteBuffer);
    } catch (_) {
      return null;
    }
  }

  bool _isPdfBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final header = utf8.decode(
      bytes.take(8).toList(),
      allowMalformed: true,
    );
    return header.startsWith('%PDF-');
  }

  List<OrderData> _filterOrders(List<OrderData> orders) {
    final query = _normalize(_query);
    if (query.isEmpty) return orders;

    return orders.where((order) {
      final receiptText = _receiptTextCache[order.id] ?? '';
      final searchable = <String>[
        order.id,
        order.productName,
        order.ukuran,
        order.frame,
        order.shippingCourier ?? '',
        order.shippingReceiptFileName ?? '',
        order.catatan,
        receiptText,
      ];

      return searchable.any((value) {
        final normalized = _normalize(value);
        if (normalized.contains(query)) return true;

        final loose = _normalizeLoose(value);
        final queryLoose = _normalizeLoose(_query);
        if (queryLoose.isNotEmpty && loose.contains(queryLoose)) return true;

        // Dimensi: 120x60 harus match 120×60 cm dan 120x60cm.
        final digitsQuery = query.replaceAll(RegExp(r'[^0-9x]'), '');
        final digitsValue = normalized.replaceAll(RegExp(r'[^0-9x]'), '');
        return digitsQuery.isNotEmpty &&
            digitsQuery.contains('x') &&
            digitsValue.contains(digitsQuery);
      });
    }).toList();
  }

  String _formatRupiah(int value) {
    final text = value.toString();
    final reversed = text.split('').reversed.toList();
    final groups = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      groups.add(reversed.sublist(i, end).reversed.join());
    }
    return 'Rp ${groups.reversed.join('.')}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.belumSelesai:
        return 'BELUM SELESAI';
      case OrderStatus.siapDikirim:
        return 'SIAP DIKIRIM';
      case OrderStatus.selesai:
        return 'SELESAI';
    }
  }

  Color _statusBackground(OrderStatus status) {
    switch (status) {
      case OrderStatus.belumSelesai:
        return const Color(0xFFFFF5DF);
      case OrderStatus.siapDikirim:
        return const Color(0xFFEFF3FF);
      case OrderStatus.selesai:
        return const Color(0xFFE9F5EC);
    }
  }

  Color _statusForeground(OrderStatus status) {
    switch (status) {
      case OrderStatus.belumSelesai:
        return const Color(0xFF9A741A);
      case OrderStatus.siapDikirim:
        return const Color(0xFF4D64A5);
      case OrderStatus.selesai:
        return const Color(0xFF3F7A4A);
    }
  }

  Future<void> _openEdit(OrderData order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditOrderPage(
          adminEmail: widget.adminEmail,
          workspaceId: widget.workspaceId,
          workspaceName: widget.workspaceName,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteOrder(OrderData order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Order?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Order ${order.id} akan dihapus dari order produksi '
                'workspace ${widget.workspaceName}. Histori pembayaran '
                'tetap dipertahankan bila sudah ada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('BATAL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB33A3A),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('HAPUS'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    final deleted = OrderStore.instance.adminRemoveOrder(
      orderId: order.id,
      workspaceId: widget.workspaceId,
    );
    if (!mounted) return;
    _message(
      deleted
          ? 'Order ${order.id} berhasil dihapus.'
          : 'Order ${order.id} gagal dihapus atau sudah tidak tersedia.',
    );
  }

  void _openReceipt(OrderData order) {
    final bytes = order.shippingReceiptImage;
    final storageUrl = order.shippingReceiptUrl?.trim();

    if (bytes != null && bytes.isNotEmpty) {
      if (_isPdfBytes(bytes)) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
        Future<void>.delayed(const Duration(minutes: 2), () {
          html.Url.revokeObjectUrl(url);
        });
        return;
      }

      _showImageDialog(
        title: 'Resi • ${order.id}',
        bytes: bytes,
        fileName: order.shippingReceiptFileName,
      );
      return;
    }

    if (storageUrl != null && storageUrl.isNotEmpty) {
      final cleanUrl = storageUrl.split('?').first.toLowerCase();
      if (cleanUrl.endsWith('.pdf')) {
        html.window.open(storageUrl, '_blank');
      } else {
        _showNetworkImageDialog(
          title: 'Resi • ${order.id}',
          url: storageUrl,
          fileName: order.shippingReceiptFileName,
        );
      }
      return;
    }

    _message('Resi untuk ${order.id} belum tersedia.');
  }

  void _showNetworkImageDialog({
    required String title,
    required String url,
    String? fileName,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF15171A),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: Color(0xFFD6B56A),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Gagal memuat file resi.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (fileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E939B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog({
    required String title,
    required Uint8List bytes,
    String? fileName,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF15171A),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: Color(0xFFD6B56A)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  if (fileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF8E939B), fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(OrderData order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  order.id,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailImage(order: order),
                  const SizedBox(height: 16),
                  _detailLine('Workspace', order.workspaceName),
                  _detailLine('Produk', order.productName),
                  _detailLine('Ukuran', order.ukuran),
                  _detailLine('Frame', order.frame),
                  _detailLine('Harga', _formatRupiah(order.price)),
                  _detailLine('Deadline', '${order.deadlineDays} hari'),
                  _detailLine('Tanggal Input', _formatDate(order.createdAt)),
                  _detailLine('Keeper Selesai', _formatDate(order.completedAt)),
                  _detailLine(
                    'Pembayaran',
                    order.isPaid ? 'SUDAH DIBAYAR' : 'BELUM DIBAYAR',
                  ),
                  _detailLine('Tanggal Bayar', _formatDate(order.paidAt)),
                  _detailLine('Kurir', order.shippingCourier ?? '-'),
                  _detailLine(
                    'File Resi',
                    order.shippingReceiptFileName ?? '-',
                  ),
                  _detailLine(
                    'Tanggal Pengiriman',
                    _formatDate(order.shippingDate),
                  ),
                  if (order.catatan.trim().isNotEmpty)
                    _detailLine('Catatan', order.catatan),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: (order.productImage == null ||
                            order.productImage!.isEmpty) &&
                            (order.productImageUrl?.trim().isNotEmpty != true)
                            ? null
                            : () {
                          final bytes = order.productImage;
                          if (bytes != null && bytes.isNotEmpty) {
                            _showImageDialog(
                              title: 'Gambar • ${order.id}',
                              bytes: bytes,
                              fileName: order.productImageFileName,
                            );
                          } else {
                            _showNetworkImageDialog(
                              title: 'Gambar • ${order.id}',
                              url: order.productImageUrl!.trim(),
                              fileName: order.productImageFileName,
                            );
                          }
                        },
                        icon: const Icon(Icons.image_outlined, size: 17),
                        label: const Text('REVIEW GAMBAR'),
                      ),
                      OutlinedButton.icon(
                        onPressed: (order.shippingReceiptImage == null ||
                            order.shippingReceiptImage!.isEmpty) &&
                            (order.shippingReceiptUrl?.trim().isNotEmpty != true)
                            ? null
                            : () => _openReceipt(order),
                        icon: const Icon(Icons.receipt_long_outlined, size: 17),
                        label: const Text('LIHAT RESI'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('TUTUP'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openEdit(order);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDIT ORDER'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF777A82), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final horizontal = media.width < 600 ? 14.0 : 28.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text('Pencarian • ${widget.workspaceName}'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: OrderStore.instance,
        builder: (context, _) {
          final allOrders = OrderStore.instance
              .getOrdersByWorkspace(widget.workspaceId)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final results = _filterOrders(allOrders);
          final indexing = _receiptIndexing.isNotEmpty;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pencarian Order',
                      style: TextStyle(
                        fontSize: media.width < 600 ? 24 : 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ukuran, frame, ID order, nomor resi, TT Order ID, nama produk, kurir, atau isi PDF resi.',
                      style: const TextStyle(
                        color: Color(0xFF777A82),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E4E9)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 570583632965 • 585870827812980285 • 120x60 • frame gold',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(Icons.close),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (indexing) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 5),
                      const Text(
                        'Membaca isi PDF resi untuk pencarian nomor resi / TT Order ID...',
                        style: TextStyle(
                          color: Color(0xFF777A82),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          '${results.length} hasil',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (_query.isNotEmpty)
                          Text(
                            'Query: $_query',
                            style: const TextStyle(
                              color: Color(0xFF7D8087),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (results.isEmpty)
                      _emptyState()
                    else
                      ...results.map(
                            (order) => _SearchOrderCard(
                          order: order,
                          onDetail: _showDetail,
                          onEdit: _openEdit,
                          onDelete: _deleteOrder,
                          onReceipt: _openReceipt,
                          formatRupiah: _formatRupiah,
                          formatDate: _formatDate,
                          statusText: _statusText,
                          statusBackground: _statusBackground,
                          statusForeground: _statusForeground,
                          isPdf: _isPdfBytes,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: const Column(
        children: [
          Icon(Icons.manage_search_outlined, size: 42, color: Color(0xFFB0B1B7)),
          SizedBox(height: 12),
          Text(
            'Order tidak ditemukan',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Coba ID order, nomor resi, TT Order ID, ukuran seperti 120x60, atau frame seperti Gold.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF777A82), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SearchOrderCard extends StatelessWidget {
  final OrderData order;
  final void Function(OrderData) onDetail;
  final Future<void> Function(OrderData) onEdit;
  final Future<void> Function(OrderData) onDelete;
  final void Function(OrderData) onReceipt;
  final String Function(int) formatRupiah;
  final String Function(DateTime?) formatDate;
  final String Function(OrderStatus) statusText;
  final Color Function(OrderStatus) statusBackground;
  final Color Function(OrderStatus) statusForeground;
  final bool Function(Uint8List) isPdf;

  const _SearchOrderCard({
    required this.order,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onReceipt,
    required this.formatRupiah,
    required this.formatDate,
    required this.statusText,
    required this.statusBackground,
    required this.statusForeground,
    required this.isPdf,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final receipt = order.shippingReceiptImage;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                order.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 7),
            _badge(statusText(order.status), statusBackground(order.status), statusForeground(order.status)),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          order.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            _pill(Icons.straighten_outlined, order.ukuran),
            _pill(Icons.crop_square_outlined, order.frame),
            _pill(Icons.payments_outlined, formatRupiah(order.price)),
            _pill(Icons.calendar_today_outlined, 'Input ${formatDate(order.createdAt)}'),
            if (order.shippingCourier != null)
              _pill(Icons.local_shipping_outlined, order.shippingCourier!),
            if (order.shippingReceiptFileName != null)
              _pill(Icons.receipt_outlined, order.shippingReceiptFileName!),
          ],
        ),
      ],
    );

    final image = SizedBox(
      width: compact ? 74 : 92,
      height: compact ? 74 : 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: order.productImage != null && order.productImage!.isNotEmpty
            ? Image.memory(
          order.productImage!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF0F0F2),
            child: const Icon(Icons.broken_image_outlined),
          ),
        )
            : (order.productImageUrl?.trim().isNotEmpty ?? false)
            ? Image.network(
          order.productImageUrl!.trim(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF0F0F2),
            child: const Icon(Icons.broken_image_outlined),
          ),
        )
            : Container(
          color: const Color(0xFFF0F0F2),
          child: const Icon(
            Icons.image_outlined,
            color: Color(0xFFB0B1B7),
          ),
        ),
      ),
    );

    final actions = Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        OutlinedButton.icon(
          onPressed: () => onDetail(order),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('DETAIL'),
        ),
        OutlinedButton.icon(
          onPressed: (receipt == null || receipt.isEmpty) &&
              (order.shippingReceiptUrl?.trim().isNotEmpty != true)
              ? null
              : () => onReceipt(order),
          icon: const Icon(Icons.receipt_long_outlined, size: 16),
          label: Text(
            ((receipt == null || receipt.isEmpty) &&
                (order.shippingReceiptUrl?.trim().isNotEmpty != true))
                ? 'RESI BELUM ADA'
                : 'LIHAT RESI',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => onEdit(order),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('EDIT ORDER'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB33A3A),
            side: const BorderSide(color: Color(0xFFE4B8B8)),
          ),
          onPressed: () => onDelete(order),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('HAPUS ORDER'),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: compact
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(width: 12),
              Expanded(child: details),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: actions),
        ],
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image,
          const SizedBox(width: 14),
          Expanded(child: details),
          const SizedBox(width: 16),
          Flexible(child: actions),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF767980)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF676A72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailImage extends StatelessWidget {
  final OrderData order;
  final double size;

  const _DetailImage({
    required this.order,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = order.productImage;
    final url = order.productImageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: size,
        color: const Color(0xFFF1F1F3),
        child: bytes != null && bytes.isNotEmpty
            ? Image.memory(bytes, fit: BoxFit.contain)
            : (url != null && url.isNotEmpty)
            ? Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: Color(0xFFB0B1B7),
          ),
        )
            : const Icon(
          Icons.image_outlined,
          size: 40,
          color: Color(0xFFB0B1B7),
        ),
      ),
    );
  }
}

