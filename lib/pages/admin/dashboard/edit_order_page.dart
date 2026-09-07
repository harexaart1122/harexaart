import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/order_store.dart';

class EditOrderPage extends StatefulWidget {
  final String adminEmail;
  final String workspaceId;
  final String workspaceName;
  final String? initialOrderId;

  const EditOrderPage({
    super.key,
    required this.adminEmail,
    required this.workspaceId,
    required this.workspaceName,
    this.initialOrderId,
  });

  @override
  State<EditOrderPage> createState() => _EditOrderPageState();
}

class _EditOrderPageState extends State<EditOrderPage> {
  final ImagePicker _picker = ImagePicker();
  String _search = '';
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _search = widget.initialOrderId?.trim() ?? '';
    OrderStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    OrderStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<OrderData> get _orders {
    final query = _search.trim().toLowerCase();
    return OrderStore.instance
        .getOrdersByWorkspace(widget.workspaceId)
        .where((order) {
      final matchesStatus = _statusFilter == null || order.status == _statusFilter;
      final matchesSearch = query.isEmpty ||
          order.id.toLowerCase().contains(query) ||
          order.productName.toLowerCase().contains(query) ||
          order.ukuran.toLowerCase().contains(query) ||
          order.frame.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: _content(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_note_outlined, size: 25),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Edit Order',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 4, backgroundColor: Color(0xFF3F7A4A)),
                const SizedBox(width: 7),
                Text(
                  widget.workspaceName.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final orders = _orders;
    final all = OrderStore.instance.getOrdersByWorkspace(widget.workspaceId);
    final unfinished = all.where((o) => o.status != OrderStatus.selesai).length;
    final finished = all.where((o) => o.status == OrderStatus.selesai).length;
    final paid = all.where((o) => o.isPaid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kontrol & Edit Order', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Admin ${widget.workspaceName} dapat memperbaiki data order, gambar, resi, status produksi, dan menghapus order yang belum masuk audit pembayaran.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF89898E), height: 1.45),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('TOTAL ORDER', '${all.length}', Icons.receipt_long_outlined),
            _kpi('MASIH PROSES', '$unfinished', Icons.pending_actions_outlined),
            _kpi('SELESAI', '$finished', Icons.check_circle_outline),
            _kpi('SUDAH DIBAYAR', '$paid', Icons.payments_outlined),
          ],
        ),
        const SizedBox(height: 22),
        _toolbar(),
        const SizedBox(height: 18),
        if (orders.isEmpty)
          _emptyState()
        else
          ...orders.map(_orderCard),
      ],
    );
  }

  Widget _kpi(String title, String value, IconData icon) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFF0F0F2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 9, color: Color(0xFF929297), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 19),
                hintText: 'Cari ID, produk, ukuran, frame...',
                filled: true,
                fillColor: const Color(0xFFF7F7F8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          _filterButton('SEMUA STATUS', null),
          _filterButton('PROSES', OrderStatus.belumSelesai),
          _filterButton('SIAP DIKIRIM', OrderStatus.siapDikirim),
          _filterButton('SELESAI', OrderStatus.selesai),
        ],
      ),
    );
  }

  Widget _filterButton(String label, OrderStatus? status) {
    final selected = _statusFilter == status;
    return OutlinedButton(
      onPressed: () => setState(() => _statusFilter = status),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFEAE9EE) : Colors.white,
        foregroundColor: const Color(0xFF3F3F44),
        side: BorderSide(color: selected ? const Color(0xFFB8B8BF) : const Color(0xFFE1E1E5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E5E9))),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFB9B9BE)),
          SizedBox(height: 12),
          Text('Order tidak ditemukan', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 5),
          Text('Coba ubah kata pencarian atau filter status.', style: TextStyle(fontSize: 11, color: Color(0xFF929297))),
        ],
      ),
    );
  }

  Widget _orderCard(OrderData order) {
    final paid = order.isPaid;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E5E9)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;
          final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Text(order.id, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(width: 9),
                _statusChip(order.status),
                if (paid) ...[
                  const SizedBox(width: 7),
                  _smallChip('PAID', const Color(0xFFE7F1E8), const Color(0xFF3F7A4A)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(order.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _detail(Icons.photo_size_select_small_outlined, 'Ukuran', order.ukuran),
                _detail(Icons.crop_square_outlined, 'Frame', order.frame),
                _detail(Icons.payments_outlined, 'Harga', _rupiah(order.price)),
                _detail(Icons.timer_outlined, 'Deadline', '${order.deadlineDays} hari'),
                _detail(Icons.calendar_today_outlined, 'Input', _dateTime(order.createdAt)),
                _detail(Icons.check_circle_outline, 'Selesai', order.completedAt == null ? '-' : _dateTime(order.completedAt!)),
              ],
            ),
            if (order.shippingCourier != null) ...[
              const SizedBox(height: 10),
              _detail(Icons.local_shipping_outlined, 'Resi', order.shippingCourier!),
            ],
          ]);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                _headerImage(order),
                const SizedBox(height: 14),
                info,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerImage(order),
                    const SizedBox(width: 18),
                    Expanded(child: info),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 13),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _actionButton('EDIT DATA', Icons.edit_outlined, () => _editData(order), primary: true),
                  _actionButton('EDIT GAMBAR', Icons.image_outlined, () => _editProductImage(order)),
                  _actionButton('EDIT RESI', Icons.local_shipping_outlined, () => _editReceipt(order)),
                  _actionButton(
                    order.status == OrderStatus.selesai ? 'KEMBALIKAN KE PROSES' : 'JADIKAN SELESAI',
                    order.status == OrderStatus.selesai ? Icons.undo_rounded : Icons.check_circle_outline,
                        () => _changeStatus(order),
                  ),
                  _actionButton('HAPUS ORDER', Icons.delete_outline, () => _deleteOrder(order), danger: true),
                ],
              ),
              if (paid)
                const Padding(
                  padding: EdgeInsets.only(top: 11),
                  child: Text(
                    'ADMIN OVERRIDE: order sudah dibayar tetap dapat dikontrol. Histori pembayaran Finance tetap disimpan sebagai audit.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8D6B29), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerImage(OrderData order) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(color: const Color(0xFFF0F0F2), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: order.productImage != null
          ? Image.memory(order.productImage!, fit: BoxFit.cover)
          : order.productImageUrl != null && order.productImageUrl!.trim().isNotEmpty
          ? Image.network(order.productImageUrl!, fit: BoxFit.cover)
          : const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9B9BA1), size: 29),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF77777E)),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(fontSize: 10, color: Color(0xFF96969C))),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _statusChip(OrderStatus status) {
    final text = status == OrderStatus.selesai ? 'SELESAI' : status == OrderStatus.siapDikirim ? 'SIAP DIKIRIM' : 'ON PROGRESS';
    return _smallChip(text, status == OrderStatus.selesai ? const Color(0xFFE7F1E8) : const Color(0xFFF2EEE5), status == OrderStatus.selesai ? const Color(0xFF3F7A4A) : const Color(0xFF866A32));
  }

  Widget _smallChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: fg, letterSpacing: .5)),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {bool primary = false, bool danger = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        backgroundColor: primary ? const Color(0xFF242428) : Colors.white,
        foregroundColor: danger ? const Color(0xFFB33A3A) : primary ? Colors.white : const Color(0xFF444449),
        side: BorderSide(color: danger ? const Color(0xFFE6CACA) : const Color(0xFFE0E0E4)),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static const List<String> _ukuranOptions = [
    '40×60 cm',
    '100×50 cm',
    '60×90 cm',
    '120×60 cm',
    '120×80 cm',
    '150×80 cm',
    '140×90 cm',
    '80×80 cm',
    '100×100 cm',
    '50×50 cm',
    '200×100 cm',
    '120×180 cm',
    'CUSTOM',
  ];

  static const List<String> _frameOptions = [
    'No Frame',
    'Frame Hitam',
    'Frame Putih',
    'Frame Gold Muda',
    'Frame Gold Tua',
    'Frame Kayu Tua',
    'Frame Kayu Muda',
    'Frame Silver',
    'CUSTOM',
  ];

  static const Map<String, Map<String, int>> _priceDatabase = {
    '40×60 cm': {
      'No Frame': 70000,
      'Frame Hitam': 100000,
      'Frame Putih': 100000,
      'Frame Gold Muda': 100000,
      'Frame Gold Tua': 100000,
      'Frame Kayu Tua': 100000,
      'Frame Kayu Muda': 100000,
      'Frame Silver': 100000,
    },
    '100×50 cm': {
      'No Frame': 140000,
      'Frame Hitam': 195000,
      'Frame Putih': 195000,
      'Frame Gold Muda': 195000,
      'Frame Gold Tua': 195000,
      'Frame Kayu Tua': 195000,
      'Frame Kayu Muda': 195000,
      'Frame Silver': 195000,
    },
    '60×90 cm': {
      'No Frame': 140000,
      'Frame Hitam': 195000,
      'Frame Putih': 195000,
      'Frame Gold Muda': 195000,
      'Frame Gold Tua': 195000,
      'Frame Kayu Tua': 195000,
      'Frame Kayu Muda': 195000,
      'Frame Silver': 195000,
    },
    '120×60 cm': {
      'No Frame': 240000,
      'Frame Hitam': 310000,
      'Frame Putih': 310000,
      'Frame Gold Muda': 310000,
      'Frame Gold Tua': 310000,
      'Frame Kayu Tua': 310000,
      'Frame Kayu Muda': 310000,
      'Frame Silver': 310000,
    },
    '120×80 cm': {
      'No Frame': 255000,
      'Frame Hitam': 335000,
      'Frame Putih': 335000,
      'Frame Gold Muda': 335000,
      'Frame Gold Tua': 335000,
      'Frame Kayu Tua': 335000,
      'Frame Kayu Muda': 335000,
      'Frame Silver': 335000,
    },
    '150×80 cm': {
      'No Frame': 300000,
      'Frame Hitam': 400000,
      'Frame Putih': 400000,
      'Frame Gold Muda': 400000,
      'Frame Gold Tua': 400000,
      'Frame Kayu Tua': 400000,
      'Frame Kayu Muda': 400000,
      'Frame Silver': 400000,
    },
    '140×90 cm': {
      'No Frame': 300000,
      'Frame Hitam': 400000,
      'Frame Putih': 400000,
      'Frame Gold Muda': 400000,
      'Frame Gold Tua': 400000,
      'Frame Kayu Tua': 400000,
      'Frame Kayu Muda': 400000,
      'Frame Silver': 400000,
    },
    '80×80 cm': {
      'No Frame': 140000,
      'Frame Hitam': 220000,
      'Frame Putih': 220000,
      'Frame Gold Muda': 220000,
      'Frame Gold Tua': 220000,
      'Frame Kayu Tua': 220000,
      'Frame Kayu Muda': 220000,
      'Frame Silver': 220000,
    },
    '100×100 cm': {
      'No Frame': 255000,
      'Frame Hitam': 335000,
      'Frame Putih': 335000,
      'Frame Gold Muda': 335000,
      'Frame Gold Tua': 335000,
      'Frame Kayu Tua': 335000,
      'Frame Kayu Muda': 335000,
      'Frame Silver': 335000,
    },
    '50×50 cm': {
      'No Frame': 70000,
      'Frame Hitam': 100000,
      'Frame Putih': 100000,
      'Frame Gold Muda': 100000,
      'Frame Gold Tua': 100000,
      'Frame Kayu Tua': 100000,
      'Frame Kayu Muda': 100000,
      'Frame Silver': 100000,
    },
    '200×100 cm': {
      'No Frame': 530000,
      'Frame Hitam': 720000,
      'Frame Putih': 720000,
      'Frame Gold Muda': 720000,
      'Frame Gold Tua': 720000,
      'Frame Kayu Tua': 720000,
      'Frame Kayu Muda': 720000,
      'Frame Silver': 720000,
    },
    '120×180 cm': {
      'No Frame': 530000,
      'Frame Hitam': 720000,
      'Frame Putih': 720000,
      'Frame Gold Muda': 720000,
      'Frame Gold Tua': 720000,
      'Frame Kayu Tua': 720000,
      'Frame Kayu Muda': 720000,
      'Frame Silver': 720000,
    },
  };

  Future<void> _editData(OrderData order) async {
    final product = TextEditingController(text: order.productName);
    final note = TextEditingController(text: order.catatan);
    final customSize = TextEditingController();
    final customFrame = TextEditingController();
    final priceController = TextEditingController(text: order.price.toString());
    final deadlineController =
    TextEditingController(text: order.deadlineDays.toString());

    String selectedSize =
    _ukuranOptions.contains(order.ukuran) ? order.ukuran : 'CUSTOM';
    String selectedFrame =
    _frameOptions.contains(order.frame) ? order.frame : 'CUSTOM';

    if (selectedSize == 'CUSTOM') {
      customSize.text = order.ukuran;
    }
    if (selectedFrame == 'CUSTOM') {
      customFrame.text = order.frame;
    }

    bool manualPrice =
        _priceDatabase[order.ukuran]?[order.frame] != order.price;

    String effectiveSize() {
      return selectedSize == 'CUSTOM' ? customSize.text.trim() : selectedSize;
    }

    String effectiveFrame() {
      return selectedFrame == 'CUSTOM'
          ? customFrame.text.trim()
          : selectedFrame;
    }

    void syncAutomaticPrice() {
      if (manualPrice) return;
      final autoPrice = _priceDatabase[effectiveSize()]?[effectiveFrame()];
      if (autoPrice != null) {
        priceController.text = autoPrice.toString();
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final autoPrice =
          _priceDatabase[effectiveSize()]?[effectiveFrame()];

          return AlertDialog(
            backgroundColor: const Color(0xFF191B1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Edit Data Order',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _field(product, 'Nama Produk'),
                    _dropdownField(
                      label: 'Ukuran',
                      value: selectedSize,
                      items: _ukuranOptions,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedSize = value;
                          syncAutomaticPrice();
                        });
                      },
                    ),
                    if (selectedSize == 'CUSTOM')
                      _field(
                        customSize,
                        'Ukuran Custom',
                        onChanged: (_) {
                          setDialogState(syncAutomaticPrice);
                        },
                      ),
                    _dropdownField(
                      label: 'Frame',
                      value: selectedFrame,
                      items: _frameOptions,
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedFrame = value;
                          syncAutomaticPrice();
                        });
                      },
                    ),
                    if (selectedFrame == 'CUSTOM')
                      _field(
                        customFrame,
                        'Frame Custom',
                        onChanged: (_) {
                          setDialogState(syncAutomaticPrice);
                        },
                      ),
                    const SizedBox(height: 2),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MODE HARGA',
                        style: TextStyle(
                          color: Color(0xFF92969D),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF24262A),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              value: false,
                              groupValue: manualPrice,
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  manualPrice = false;
                                  syncAutomaticPrice();
                                });
                              },
                              title: const Text(
                                'OTOMATIS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                autoPrice == null
                                    ? 'Pilih ukuran + frame standard'
                                    : _rupiah(autoPrice),
                                style: const TextStyle(
                                  color: Color(0xFF92969D),
                                  fontSize: 10,
                                ),
                              ),
                              activeColor: const Color(0xFFD9B55F),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 7),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              value: true,
                              groupValue: manualPrice,
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  manualPrice = true;
                                });
                              },
                              title: const Text(
                                'MANUAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Harga custom admin',
                                style: TextStyle(
                                  color: Color(0xFF92969D),
                                  fontSize: 10,
                                ),
                              ),
                              activeColor: const Color(0xFFD9B55F),
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _field(
                      priceController,
                      manualPrice
                          ? 'Harga Final (Manual)'
                          : 'Harga Final (Otomatis)',
                      number: true,
                      enabled: manualPrice,
                    ),
                    if (!manualPrice)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          autoPrice == null
                              ? 'Kombinasi ini belum memiliki harga standard. Pilih MANUAL.'
                              : 'Harga otomatis mengikuti tabel Input Order.',
                          style: const TextStyle(
                            color: Color(0xFF92969D),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    _field(
                      deadlineController,
                      'Deadline (hari)',
                      number: true,
                    ),
                    _field(note, 'Catatan', maxLines: 4),
                    const SizedBox(height: 8),
                    const Text(
                      'ID order dan tanggal Input Order tidak dapat diubah.',
                      style: TextStyle(
                        color: Color(0xFF8F939A),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('BATAL'),
              ),
              ElevatedButton(
                onPressed: () {
                  final size = effectiveSize();
                  final frame = effectiveFrame();
                  final parsedPrice = int.tryParse(
                    priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                      0;
                  final parsedDeadline =
                      int.tryParse(deadlineController.text) ?? 0;

                  if (size.isEmpty ||
                      frame.isEmpty ||
                      parsedPrice <= 0 ||
                      parsedDeadline <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ukuran, frame, harga, dan deadline wajib valid.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (!manualPrice && autoPrice == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Harga otomatis belum tersedia untuk kombinasi tersebut. Pilih MANUAL.',
                        ),
                      ),
                    );
                    return;
                  }

                  final ok = OrderStore.instance.adminEditOrder(
                    orderId: order.id,
                    workspaceId: widget.workspaceId,
                    productName: product.text,
                    ukuran: size,
                    frame: frame,
                    price: parsedPrice,
                    deadlineDays: parsedDeadline,
                    catatan: note.text,
                  );

                  Navigator.pop(dialogContext, ok);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9B55F),
                  foregroundColor: const Color(0xFF151619),
                ),
                child: const Text(
                  'SIMPAN PERUBAHAN',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );

    product.dispose();
    note.dispose();
    customSize.dispose();
    customFrame.dispose();
    priceController.dispose();
    deadlineController.dispose();

    if (saved == true) {
      _message('Data ${order.id} berhasil diperbarui.');
    }
  }

  Widget _field(TextEditingController controller, String label, {bool number = false, int maxLines = 1, bool enabled = true, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        enabled: enabled,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF92969D), fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF24262A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF24262A),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        iconEnabledColor: const Color(0xFFD9B55F),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF92969D),
            fontSize: 11,
          ),
          filled: true,
          fillColor: const Color(0xFF24262A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide.none,
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Future<void> _editProductImage(OrderData order) async {
    if (order.isPaid) {
      _message('Order yang sudah dibayar dikunci untuk audit Finance.');
      return;
    }
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2200);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ok = OrderStore.instance.adminEditOrder(
        orderId: order.id,
        workspaceId: widget.workspaceId,
        productName: order.productName,
        ukuran: order.ukuran,
        frame: order.frame,
        price: order.price,
        deadlineDays: order.deadlineDays,
        catatan: order.catatan,
        productImage: bytes,
        productImageFileName: picked.name,
        replaceProductImage: true,
      );
      _message(ok ? 'Gambar ${order.id} berhasil diganti.' : 'Gagal mengganti gambar.');
    } catch (_) {
      _message('Gagal membaca gambar. Coba file lain.');
    }
  }

  Future<void> _editReceipt(OrderData order) async {
    String? courier = order.shippingCourier;
    Uint8List? image = order.shippingReceiptImage;
    String? fileName = order.shippingReceiptFileName;
    DateTime? shippingDate = order.shippingDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF191B1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Edit Resi / Pengiriman', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.id, style: const TextStyle(color: Color(0xFFD9B55F), fontWeight: FontWeight.w800)),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: courier,
                  dropdownColor: const Color(0xFF24262A),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Jasa Kirim', labelStyle: TextStyle(color: Color(0xFF92969D))),
                  items: const ['JNE', 'J&T', 'SiCepat', 'AnterAja', 'POS Indonesia', 'Ninja Xpress', 'Lainnya']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => courier = value),
                ),
                const SizedBox(height: 15),
                InkWell(
                  onTap: () async {
                    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2200);
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    setDialogState(() {
                      image = bytes;
                      fileName = picked.name;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(color: const Color(0xFF24262A), borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: image != null
                        ? Image.memory(image!, fit: BoxFit.cover)
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: Color(0xFF9B9EA5), size: 30), SizedBox(height: 8), Text('Pilih foto / screenshot resi', style: TextStyle(color: Color(0xFF9B9EA5), fontSize: 11))]),
                  ),
                ),
                if (fileName != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(fileName!, style: const TextStyle(color: Color(0xFF8F939A), fontSize: 10))),
                const SizedBox(height: 12),
                Row(children: [const Icon(Icons.event_outlined, color: Color(0xFFD9B55F), size: 18), const SizedBox(width: 8), Text(shippingDate == null ? 'Tanggal belum diatur' : _dateTime(shippingDate!), style: const TextStyle(color: Colors.white, fontSize: 11))]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('BATAL')),
            ElevatedButton(
              onPressed: courier == null || image == null
                  ? null
                  : () {
                final ok = OrderStore.instance.adminEditOrder(
                  orderId: order.id,
                  workspaceId: widget.workspaceId,
                  productName: order.productName,
                  ukuran: order.ukuran,
                  frame: order.frame,
                  price: order.price,
                  deadlineDays: order.deadlineDays,
                  catatan: order.catatan,
                  shippingCourier: courier,
                  shippingReceiptImage: image,
                  shippingReceiptFileName: fileName,
                  shippingDate: shippingDate ?? DateTime.now(),
                  replaceShippingReceipt: true,
                );
                Navigator.pop(dialogContext, ok);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9B55F), foregroundColor: const Color(0xFF151619)),
              child: const Text('SIMPAN RESI', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (result == true) _message('Data resi ${order.id} berhasil diperbarui.');
  }

  Future<void> _changeStatus(OrderData order) async {
    final selected = await showDialog<OrderStatus>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF191B1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Kontrol Status ${order.id}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Admin dapat mengubah seluruh flow order. Perubahan akan langsung masuk ke OrderStore dan dipantau Keeper.',
                style: TextStyle(color: Color(0xFF9DA1A8), fontSize: 11, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            _statusChoice(dialogContext, OrderStatus.belumSelesai, 'BELUM SELESAI', 'Kembali ke proses / dikerjakan'),
            _statusChoice(dialogContext, OrderStatus.siapDikirim, 'SIAP DIKIRIM', 'Produksi selesai, menunggu pengiriman'),
            _statusChoice(dialogContext, OrderStatus.selesai, 'SELESAI', 'Order selesai dan dapat diproses Finance'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
        ],
      ),
    );

    if (selected == null || selected == order.status) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Perubahan Status'),
        content: Text(
          'Admin akan mengubah ${order.id} dari ${_statusLabel(order.status)} menjadi ${_statusLabel(selected)}.\n\n'
              '${order.isPaid ? 'Order ini sudah dibayar. Histori pembayaran Finance tetap dipertahankan sebagai audit.\n\n' : ''}'
              'Perubahan akan langsung terlihat pada Keeper.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('UBAH STATUS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = OrderStore.instance.adminUpdateStatus(
      orderId: order.id,
      workspaceId: widget.workspaceId,
      newStatus: selected,
    );
    _message(ok
        ? '${order.id} berhasil diubah menjadi ${_statusLabel(selected)}.'
        : 'Perubahan status ditolak.');
  }

  Widget _statusChoice(
      BuildContext dialogContext,
      OrderStatus status,
      String title,
      String subtitle,
      ) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        status == OrderStatus.selesai
            ? Icons.check_circle_outline
            : status == OrderStatus.siapDikirim
            ? Icons.local_shipping_outlined
            : Icons.pending_actions_outlined,
        color: status == OrderStatus.selesai
            ? const Color(0xFF4B8B5A)
            : status == OrderStatus.siapDikirim
            ? const Color(0xFFC48D38)
            : const Color(0xFF6B7078),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      onTap: () => Navigator.pop(dialogContext, status),
    );
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.belumSelesai:
        return 'BELUM SELESAI';
      case OrderStatus.siapDikirim:
        return 'SIAP DIKIRIM';
      case OrderStatus.selesai:
        return 'SELESAI';
    }
  }

  Future<void> _deleteOrder(OrderData order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Order?'),
        content: Text('Order ${order.id} akan dihapus dari Order Store ${widget.workspaceName}. Jika order sudah dibayar, histori pembayaran Finance tetap dipertahankan sebagai audit. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB33A3A), foregroundColor: Colors.white),
            child: const Text('HAPUS', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = OrderStore.instance.adminRemoveOrder(orderId: order.id, workspaceId: widget.workspaceId);
    _message(ok ? 'Order ${order.id} berhasil dihapus.' : 'Order tidak dapat dihapus.');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _rupiah(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
      buffer.write(text[i]);
    }
    return 'Rp $buffer';
  }

  String _dateTime(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
