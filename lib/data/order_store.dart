

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_repository.dart';

/// ============================================================
/// STATUS ORDER / PRODUKSI
/// ============================================================
///
/// Status ini dipakai bersama oleh:
/// - Admin
/// - Keeper
/// - Finance
///
/// Alur produksi:
///
/// belumSelesai
///     ↓
/// siapDikirim
///     ↓
/// selesai
///
/// Catatan:
/// Status produksi TIDAK sama dengan status pembayaran.
///
/// SELESAI ≠ SUDAH DIBAYAR
/// ============================================================

enum OrderStatus {
  belumSelesai,
  siapDikirim,
  selesai,
}

/// ============================================================
/// WORKFLOW KEEPER
/// ============================================================
/// Tahap operasional Keeper. Status ini menentukan menu tempat order berada.
enum KeeperStage {
  orderanMasuk,
  sedangDikerjakan,
  inputResi,
  selesaiDikerjakan,
}

/// ============================================================
/// STATUS PEMBAYARAN
/// ============================================================
///
/// Status pembayaran sengaja dipisahkan dari OrderStatus.
///
/// Order:
///   belumSelesai / siapDikirim / selesai
///
/// Pembayaran:
///   belumDibayar / sudahDibayar
///
/// Dengan begitu:
///
/// SELESAI
/// tidak otomatis berarti
/// SUDAH DIBAYAR.
/// ============================================================

enum PaymentStatus {
  belumDibayar,
  sudahDibayar,
}

/// ============================================================
/// STATUS PACKING / PENGIRIMAN OPERASIONAL
/// ============================================================
///
/// Status ini terpisah dari produksi dan pembayaran.
///
/// SELESAI PRODUKSI
///      ↓
/// BELUM DIPACKING
///      ↓ PACKING LANGSUNG
/// SUDAH DIPACKING
///      ↓ SUDAH DIKIRIM
/// SUDAH DIKIRIM
///
/// Data historis tidak dihapus. Timestamp dipakai untuk arsip
/// harian, mingguan, bulanan, dan rentang custom.
/// ============================================================
enum PackingStatus {
  belumDipacking,
  sudahDipacking,
  sudahDikirim,
}

/// ============================================================
/// DATA ORDER
/// ============================================================
///
/// Satu OrderData mewakili satu order yang masuk melalui
/// halaman Input Order.
///
/// Harga di sini adalah harga FINAL dari Input Order.
///
/// Finance TIDAK membuat atau menginput harga kedua.
///
/// HarexaArt dan Lavanya Art dipisahkan menggunakan workspaceId.
/// ============================================================

class OrderData {
  /// ----------------------------------------------------------
  /// IDENTITAS ORDER
  /// ----------------------------------------------------------

  /// ID unik order.
  ///
  /// Contoh:
  /// HRX-025
  /// LVA-014
  final String id;

  /// ID workspace.
  ///
  /// Nilai yang digunakan:
  /// - harexaart
  /// - lavanya_art
  final String workspaceId;

  /// Nama workspace untuk kebutuhan tampilan.
  final String workspaceName;

  /// Email admin yang membuat order.
  final String adminEmail;

  /// ----------------------------------------------------------
  /// DETAIL PRODUK
  /// ----------------------------------------------------------

  /// Nama produk.
  String productName;

  /// Ukuran lukisan.
  String ukuran;

  /// Jenis frame.
  String frame;

  /// Harga FINAL order dari Input Order.
  ///
  /// Finance akan membaca nilai ini.
  /// Tidak boleh ada nominal kedua.
  int price;

  /// ----------------------------------------------------------
  /// DATA ORDER TAMBAHAN
  /// ----------------------------------------------------------

  /// Deadline pengerjaan dalam hari.
  int deadlineDays;

  /// Catatan/order note dari Input Order.
  String catatan;

  /// ----------------------------------------------------------
  /// FOTO PRODUK
  /// ----------------------------------------------------------
  ///
  /// Foto menjadi bagian dari data order.
  ///
  /// Untuk runtime/web:
  /// productImage dapat menyimpan bytes gambar.
  ///
  /// Untuk tahap Supabase:
  /// productImageUrl dapat menyimpan URL Storage.
  /// ----------------------------------------------------------

  /// Bytes foto produk.
  Uint8List? productImage;

  /// Nama file foto produk.
  String? productImageFileName;

  /// URL foto produk.
  ///
  /// Disiapkan untuk Supabase Storage.
  String? productImageUrl;

  /// ----------------------------------------------------------
  /// STATUS PRODUKSI
  /// ----------------------------------------------------------

  /// Status order/produksi.
  OrderStatus status;

  /// ----------------------------------------------------------
  /// TIMESTAMP ORDER
  /// ----------------------------------------------------------

  /// Waktu ketika order dibuat/input oleh Admin.
  ///
  /// Timestamp ini TIDAK boleh diganti ketika Keeper menyelesaikan
  /// order atau ketika Admin melakukan pembayaran.
  final DateTime createdAt;

  /// Waktu ketika Keeper mulai mengerjakan order.
  /// Null jika order belum mulai dikerjakan.
  DateTime? startedAt;

  /// Waktu ketika order berpindah ke SIAP DIKIRIM / INPUT RESI.
  /// Null jika order belum pernah mencapai tahap tersebut.
  DateTime? readyToShipAt;

  /// Waktu ketika Keeper menyelesaikan order.
  ///
  /// Null selama order belum pernah selesai.
  ///
  /// Timestamp ini hanya diisi ketika order benar-benar menjadi
  /// SELESAI.
  DateTime? completedAt;

  /// ----------------------------------------------------------
  /// STATUS PEMBAYARAN
  /// ----------------------------------------------------------

  /// Status pembayaran.
  ///
  /// Default:
  /// BELUM DIBAYAR
  PaymentStatus paymentStatus;

  /// Waktu ketika Admin memfinalisasi pembayaran.
  ///
  /// Null jika belum dibayar.
  ///
  /// Timestamp ini terpisah dari createdAt dan completedAt.
  DateTime? paidAt;

  /// ----------------------------------------------------------
  /// DATA PENGIRIMAN
  /// ----------------------------------------------------------
  ///
  /// Semua field ini null sebelum pengiriman diinput.
  String? shippingCourier;

  Uint8List? shippingReceiptImage;

  String? shippingReceiptFileName;

  /// URL PDF/foto resi dari Supabase Storage.
  /// Dipakai agar resi tetap bisa dibuka lintas perangkat setelah reload.
  String? shippingReceiptUrl;

  DateTime? shippingDate;

  /// ----------------------------------------------------------
  /// WORKFLOW KEEPER
  /// ----------------------------------------------------------

  KeeperStage keeperStage;
  bool requiresReceiptBeforeWork;

  /// ----------------------------------------------------------
  /// WORKFLOW PACKING / PENGIRIMAN
  /// ----------------------------------------------------------

  PackingStatus packingStatus;

  /// Waktu ketika tim packing mengonfirmasi order sudah dipacking.
  DateTime? packedAt;

  /// Waktu ketika order benar-benar ditandai sudah dikirim.
  DateTime? shippedAt;

  /// Waktu ketika resi order sudah dikirim ke proses print.
  /// Arsip operasional hanya dibuka setelah resi tercetak dan order dipacking.
  DateTime? receiptPrintedAt;

  /// ==========================================================
  /// CONSTRUCTOR
  /// ==========================================================

  OrderData({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.adminEmail,
    required this.productName,
    required this.ukuran,
    required this.frame,
    required this.price,
    this.deadlineDays = 5,
    this.catatan = '',
    this.productImage,
    this.productImageFileName,
    this.productImageUrl,
    this.status = OrderStatus.belumSelesai,
    required this.createdAt,
    this.startedAt,
    this.readyToShipAt,
    this.completedAt,
    this.paymentStatus = PaymentStatus.belumDibayar,
    this.paidAt,
    this.shippingCourier,
    this.shippingReceiptImage,
    this.shippingReceiptFileName,
    this.shippingReceiptUrl,
    this.shippingDate,
    this.keeperStage = KeeperStage.orderanMasuk,
    this.requiresReceiptBeforeWork = false,
    this.packingStatus = PackingStatus.belumDipacking,
    this.packedAt,
    this.shippedAt,
    this.receiptPrintedAt,
  });

  /// ==========================================================
  /// COPY WITH
  /// ==========================================================

  OrderData copyWith({
    String? id,
    String? workspaceId,
    String? workspaceName,
    String? adminEmail,
    String? productName,
    String? ukuran,
    String? frame,
    int? price,
    int? deadlineDays,
    String? catatan,
    Uint8List? productImage,
    String? productImageFileName,
    String? productImageUrl,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? readyToShipAt,
    DateTime? completedAt,
    PaymentStatus? paymentStatus,
    DateTime? paidAt,
    String? shippingCourier,
    Uint8List? shippingReceiptImage,
    String? shippingReceiptFileName,
    String? shippingReceiptUrl,
    DateTime? shippingDate,
    KeeperStage? keeperStage,
    bool? requiresReceiptBeforeWork,
    PackingStatus? packingStatus,
    DateTime? packedAt,
    DateTime? shippedAt,
    DateTime? receiptPrintedAt,
  }) {
    return OrderData(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      workspaceName: workspaceName ?? this.workspaceName,
      adminEmail: adminEmail ?? this.adminEmail,
      productName: productName ?? this.productName,
      ukuran: ukuran ?? this.ukuran,
      frame: frame ?? this.frame,
      price: price ?? this.price,
      deadlineDays: deadlineDays ?? this.deadlineDays,
      catatan: catatan ?? this.catatan,
      productImage: productImage ?? this.productImage,
      productImageFileName:
      productImageFileName ?? this.productImageFileName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      readyToShipAt: readyToShipAt ?? this.readyToShipAt,
      completedAt: completedAt ?? this.completedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      shippingCourier: shippingCourier ?? this.shippingCourier,
      shippingReceiptImage:
      shippingReceiptImage ?? this.shippingReceiptImage,
      shippingReceiptFileName:
      shippingReceiptFileName ?? this.shippingReceiptFileName,
      shippingReceiptUrl:
      shippingReceiptUrl ?? this.shippingReceiptUrl,
      shippingDate: shippingDate ?? this.shippingDate,
      keeperStage: keeperStage ?? this.keeperStage,
      requiresReceiptBeforeWork:
      requiresReceiptBeforeWork ?? this.requiresReceiptBeforeWork,
      packingStatus: packingStatus ?? this.packingStatus,
      packedAt: packedAt ?? this.packedAt,
      shippedAt: shippedAt ?? this.shippedAt,
      receiptPrintedAt: receiptPrintedAt ?? this.receiptPrintedAt,
    );
  }

  /// ==========================================================
  /// HELPER STATUS
  /// ==========================================================

  /// Apakah order sudah benar-benar selesai?
  bool get isCompleted {
    return status == OrderStatus.selesai;
  }

  /// Apakah order belum dibayar?
  bool get isUnpaid {
    return paymentStatus == PaymentStatus.belumDibayar;
  }

  /// Apakah order sudah dibayar?
  bool get isPaid {
    return paymentStatus == PaymentStatus.sudahDibayar;
  }

  /// Apakah order memenuhi syarat dasar untuk pembayaran?
  ///
  /// Syarat:
  /// 1. status produksi SELESAI
  /// 2. payment status BELUM DIBAYAR
  /// 3. completedAt tersedia
  /// 4. paidAt belum ada
  /// 5. harga valid
  bool get isEligibleForPayment {
    return status == OrderStatus.selesai &&
        paymentStatus == PaymentStatus.belumDibayar &&
        completedAt != null &&
        paidAt == null &&
        price > 0;
  }

  bool get isKeeperIncoming => keeperStage == KeeperStage.orderanMasuk;
  bool get isKeeperInProgress =>
      keeperStage == KeeperStage.sedangDikerjakan;
  bool get isKeeperWaitingForReceipt =>
      keeperStage == KeeperStage.inputResi;
  bool get isKeeperFinished =>
      keeperStage == KeeperStage.selesaiDikerjakan;
}

/// ============================================================
/// ORDER STORE
/// ============================================================
///
/// Tempat penampungan order bersama untuk:
///
/// - Admin
/// - Keeper
/// - Finance
///
/// Saat ini masih memory/local runtime.
///
/// Nanti dapat disambungkan ke Supabase.
///
/// Workspace WAJIB dipakai saat mengambil data agar:
///
/// HarexaArt
/// dan
/// Lavanya Art
///
/// tidak pernah tercampur.
/// ============================================================

class OrderStore extends ChangeNotifier {
  /// ==========================================================
  /// SINGLETON
  /// ==========================================================

  OrderStore._internal();

  static final OrderStore instance = OrderStore._internal();

  /// Repository Supabase. OrderStore tetap menjadi source of truth
  /// untuk seluruh UI, sementara perubahan disimpan ke database.
  final OrderRepository _repository = OrderRepository();

  /// ==========================================================
  /// PENAMPUNGAN ORDER
  /// ==========================================================

  final List<OrderData> _orders = [];

  /// ==========================================================
  /// SEMUA ORDER
  /// ==========================================================

  List<OrderData> get orders {
    return List.unmodifiable(_orders);
  }

  /// ==========================================================
  /// LOAD ORDER DARI SUPABASE KE MEMORY
  /// ==========================================================
  ///
  /// Dipakai ketika workspace pertama kali dibuka.
  ///
  /// Berbeda dengan addOrder(), method ini TIDAK melakukan INSERT
  /// ke Supabase karena order sudah berasal dari Supabase.
  /// ==========================================================
  RealtimeChannel? _ordersChannel;
  bool _realtimeStarted = false;

  void hydrateOrders(List<OrderData> orders) {
    _orders
      ..clear()
      ..addAll(orders);
    notifyListeners();
  }

  /// Ambil data permanen dari Supabase setiap kali modul dibuka/reload.
  Future<void> loadFromSupabase({String? workspaceId}) async {
    final data = workspaceId == null || workspaceId.trim().isEmpty
        ? await _repository.fetchOrders()
        : await _repository.fetchOrdersByWorkspace(workspaceId);
    hydrateOrders(data);
  }

  /// Satu listener realtime untuk seluruh modul Admin/Keeper/Monitoring.
  /// Payload langsung dimasukkan ke OrderStore tanpa membuat order baru.
  void startRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;

    final client = Supabase.instance.client;
    _ordersChannel = client
        .channel('harexaart-orders-realtime')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        final event = payload.eventType;

        if (event == PostgresChangeEvent.delete) {
          final id = payload.oldRecord['id']?.toString();
          if (id == null) return;
          _orders.removeWhere((order) => order.id == id);
          notifyListeners();
          return;
        }

        final record = payload.newRecord;
        if (record.isEmpty) return;

        final incoming = OrderDataMapper.fromSupabaseMap(
          Map<String, dynamic>.from(record),
        );
        final index = _orders.indexWhere(
              (order) => order.id == incoming.id,
        );

        if (index == -1) {
          _orders.insert(0, incoming);
        } else {
          _orders[index] = incoming;
        }
        notifyListeners();
      },
    )
        .subscribe();
  }

  /// ==========================================================
  /// TAMBAH ORDER
  /// ==========================================================
  ///
  /// Dipanggil oleh Input Order setelah order dikonfirmasi.
  ///
  /// Harga harus berasal dari InputOrderPage._totalPrice.
  ///
  /// Payment status selalu mulai dari:
  /// BELUM DIBAYAR.
  ///
  /// Tanggal pembayaran belum ada.
  Future<OrderData> addOrder(OrderData order) async {
    // JANGAN masukkan order ke memory sebagai order sukses terlebih dahulu.
    // Supabase harus berhasil menyimpan gambar + resi + row database.
    final savedOrder = await _repository.insertOrder(order);

    final index = _orders.indexWhere((item) => item.id == savedOrder.id);
    if (index == -1) {
      _orders.insert(0, savedOrder);
    } else {
      _orders[index] = savedOrder;
    }
    notifyListeners();
    return savedOrder;
  }

  /// ==========================================================
  /// UPDATE STATUS PRODUKSI
  /// ==========================================================
  ///
  /// Dipakai oleh Keeper.
  ///
  /// Ketika status berubah menjadi SELESAI:
  ///
  /// completedAt = DateTime.now()
  ///
  /// Timestamp ini hanya dibuat ketika completedAt sebelumnya
  /// masih null.
  ///
  /// Dengan begitu tanggal selesai Keeper tidak tertimpa
  /// oleh perubahan status berikutnya.
  ///
  /// createdAt TIDAK PERNAH DIUBAH.
  void updateStatus(
      String orderId,
      OrderStatus newStatus,
      ) {
    final index = _orders.indexWhere(
          (order) => order.id == orderId,
    );

    if (index == -1) {
      return;
    }

    final OrderData order = _orders[index];

    order.status = newStatus;

    final now = DateTime.now();

    // Sinkronkan status produksi dengan posisi Keeper agar semua modul
    // membaca alur yang sama dari satu OrderData.
    if (newStatus == OrderStatus.selesai) {
      order.startedAt ??= now;
      order.keeperStage = KeeperStage.selesaiDikerjakan;
      order.completedAt ??= now;
    } else if (newStatus == OrderStatus.siapDikirim) {
      order.startedAt ??= now;
      order.keeperStage = KeeperStage.inputResi;
      order.readyToShipAt ??= now;
    } else {
      order.startedAt ??= now;
      if (order.keeperStage == KeeperStage.selesaiDikerjakan) {
        order.keeperStage = KeeperStage.sedangDikerjakan;
      }
    }

    notifyListeners();
    unawaited(_persistOrder(order));
  }

  /// ==========================================================
  /// UPDATE DATA PENGIRIMAN
  /// ==========================================================
  ///
  /// Keeper menggunakan fungsi ini ketika data pengiriman
  /// sudah dimasukkan.
  ///
  /// Data resi tersimpan di OrderData dan Keeper tetap berada
  /// di tahap INPUT RESI / SIAP DIKIRIM sampai Keeper benar-benar
  /// menyelesaikan order.
  ///
  /// Deadline tetap berdiri sendiri dan tidak diubah.
  void updateShipping({
    required String orderId,
    required String courier,
    required Uint8List receiptImage,
    String? receiptFileName,
    DateTime? shippingDate,
  }) {
    final index = _orders.indexWhere(
          (order) => order.id == orderId,
    );

    if (index == -1) {
      return;
    }

    final OrderData order = _orders[index];

    order.shippingCourier = courier.trim();
    order.shippingReceiptImage = receiptImage;
    order.shippingReceiptFileName = receiptFileName;
    order.shippingDate = shippingDate ?? DateTime.now();

    // Setelah data resi disimpan, order berada di tahap
    // SIAP DIKIRIM / INPUT RESI sampai Keeper menekan SELESAI.
    if (order.status != OrderStatus.selesai) {
      order.keeperStage = KeeperStage.inputResi;
      order.startedAt ??= order.shippingDate;
      order.readyToShipAt ??= order.shippingDate;
    }

    notifyListeners();
    unawaited(_persistOrder(order));
  }

  /// ==========================================================
  /// MEMULAI PENGERJAAN KEEPER
  /// ==========================================================

  bool startKeeperWork({
    required String orderId,
    required String workspaceId,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.keeperStage != KeeperStage.orderanMasuk) return false;
    if (order.status == OrderStatus.selesai) return false;

    final now = DateTime.now();
    order.startedAt ??= now;

    order.keeperStage = order.requiresReceiptBeforeWork
        ? KeeperStage.inputResi
        : KeeperStage.sedangDikerjakan;

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// PINDAH KE INPUT RESI
  /// ==========================================================

  bool moveKeeperToReceiptInput({
    required String orderId,
    required String workspaceId,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.keeperStage != KeeperStage.sedangDikerjakan) {
      return false;
    }

    order.keeperStage = KeeperStage.inputResi;
    order.startedAt ??= DateTime.now();
    order.readyToShipAt ??= DateTime.now();
    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// SELESAIKAN LANGSUNG DARI SEDANG DIKERJAKAN
  /// ==========================================================
  ///
  /// Tombol "SELESAIKAN SEKARANG" adalah jalur langsung untuk
  /// order yang sudah selesai dikerjakan tanpa menunggu input resi.
  ///
  /// Jalur ini TIDAK mengisi data pengiriman secara otomatis.
  /// completedAt hanya dibuat satu kali dan tidak menimpa tanggal
  /// input order (createdAt).
  bool completeKeeperWorkNow({
    required String orderId,
    required String workspaceId,
    DateTime? completionDate,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.keeperStage != KeeperStage.sedangDikerjakan) {
      return false;
    }
    if (order.paymentStatus == PaymentStatus.sudahDibayar) {
      return false;
    }

    final completionTimestamp = completionDate ?? DateTime.now();
    order.startedAt ??= completionTimestamp;
    order.status = OrderStatus.selesai;
    order.keeperStage = KeeperStage.selesaiDikerjakan;
    order.completedAt ??= completionTimestamp;

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// SELESAIKAN DARI SIAP DIKIRIM / INPUT RESI
  /// ==========================================================
  ///
  /// Setelah Keeper menginput resi, order TETAP berada di tahap
  /// SIAP DIKIRIM (KeeperStage.inputResi). Order baru masuk ke
  /// SELESAI setelah tombol "SELESAIKAN ORDERAN" ditekan.
  bool completeKeeperWorkFromReceipt({
    required String orderId,
    required String workspaceId,
    DateTime? completionDate,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.keeperStage != KeeperStage.inputResi) {
      return false;
    }
    if (order.paymentStatus == PaymentStatus.sudahDibayar) {
      return false;
    }

    if (order.shippingCourier == null ||
        order.shippingCourier!.trim().isEmpty ||
        order.shippingReceiptImage == null) {
      return false;
    }

    final completionTimestamp = completionDate ?? DateTime.now();
    order.startedAt ??= order.shippingDate ?? completionTimestamp;
    order.readyToShipAt ??= order.shippingDate ?? completionTimestamp;
    order.status = OrderStatus.selesai;
    order.keeperStage = KeeperStage.selesaiDikerjakan;
    order.completedAt ??= completionTimestamp;

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// KOMPATIBILITAS NAMA LAMA
  /// ==========================================================
  ///
  /// Tetap dipertahankan agar modul lama tidak langsung rusak.
  /// Untuk UI Keeper baru, gunakan completeKeeperWorkNow() atau
  /// completeKeeperWorkFromReceipt() sesuai jalurnya.
  bool completeKeeperWork({
    required String orderId,
    required String workspaceId,
    DateTime? completionDate,
  }) {
    return completeKeeperWorkNow(
      orderId: orderId,
      workspaceId: workspaceId,
      completionDate: completionDate,
    );
  }

  /// ==========================================================
  /// PACKING LANGSUNG
  /// ==========================================================
  ///
  /// Hanya order yang sudah SELESAI produksi dan belum dipacking
  /// yang boleh masuk ke tahap packing.
  ///
  /// Order tidak dihapus dari OrderStore. Status packing + packedAt
  /// menjadi jejak historis untuk arsip.
  bool markOrderPacked({
    required String orderId,
    required String workspaceId,
    DateTime? packingDate,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.status != OrderStatus.selesai) return false;
    if (order.keeperStage != KeeperStage.selesaiDikerjakan) return false;
    if (order.packingStatus != PackingStatus.belumDipacking) return false;

    final timestamp = packingDate ?? DateTime.now();
    order.packingStatus = PackingStatus.sudahDipacking;
    order.packedAt = timestamp;
    order.shippedAt = null;

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// TANDA RESI SUDAH DIKIRIM KE PROSES PRINT
  /// ==========================================================
  ///
  /// Method ini tidak menghapus order dan tidak mengubah status produksi.
  /// Dipakai Monitoring untuk mencatat bahwa resi sudah masuk proses print.
  bool markReceiptPrinted({
    required String orderId,
    required String workspaceId,
    DateTime? printDate,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.status != OrderStatus.selesai) return false;
    if (order.keeperStage != KeeperStage.selesaiDikerjakan) return false;
    if (order.shippingReceiptImage == null) return false;

    order.receiptPrintedAt = printDate ?? DateTime.now();
    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// Menandai banyak resi sekaligus sudah masuk proses print.
  int markReceiptsPrinted({
    required List<String> orderIds,
    DateTime? printDate,
  }) {
    if (orderIds.isEmpty) return 0;

    final ids = orderIds.toSet();
    final timestamp = printDate ?? DateTime.now();
    var count = 0;

    for (final order in _orders) {
      if (!ids.contains(order.id)) continue;
      if (order.status != OrderStatus.selesai) continue;
      if (order.keeperStage != KeeperStage.selesaiDikerjakan) continue;
      if (order.shippingReceiptImage == null) continue;
      if (order.receiptPrintedAt != null) continue;

      order.receiptPrintedAt = timestamp;
      unawaited(_persistOrder(order));
      count++;
    }

    if (count > 0) notifyListeners();
    return count;
  }

  /// Menandai banyak order sekaligus sudah dipacking.
  int markOrdersPacked({
    required List<String> orderIds,
    DateTime? packingDate,
  }) {
    if (orderIds.isEmpty) return 0;

    final ids = orderIds.toSet();
    final timestamp = packingDate ?? DateTime.now();
    var count = 0;

    for (final order in _orders) {
      if (!ids.contains(order.id)) continue;
      if (order.status != OrderStatus.selesai) continue;
      if (order.keeperStage != KeeperStage.selesaiDikerjakan) continue;
      if (order.packingStatus != PackingStatus.belumDipacking) continue;

      order.packingStatus = PackingStatus.sudahDipacking;
      order.packedAt = timestamp;
      order.shippedAt = null;
      unawaited(_persistOrder(order));
      count++;
    }

    if (count > 0) notifyListeners();
    return count;
  }

  /// ==========================================================
  /// TANDA SUDAH DIKIRIM
  /// ==========================================================
  ///
  /// Hanya order yang sudah dipacking yang boleh ditandai dikirim.
  /// Data order tetap dipertahankan untuk arsip.
  bool markOrderShipped({
    required String orderId,
    required String workspaceId,
    DateTime? shippingDate,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.packingStatus != PackingStatus.sudahDipacking) return false;

    final timestamp = shippingDate ?? DateTime.now();
    order.packingStatus = PackingStatus.sudahDikirim;
    order.shippedAt = timestamp;

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// ORDER SUDAH DIPACKING
  /// ==========================================================
  List<OrderData> getPackedOrdersByWorkspace(String workspaceId) {
    return getOrdersByWorkspace(workspaceId)
        .where((order) =>
    order.packingStatus == PackingStatus.sudahDipacking ||
        order.packingStatus == PackingStatus.sudahDikirim)
        .toList();
  }

  /// ==========================================================
  /// ORDER SUDAH DIKIRIM
  /// ==========================================================
  List<OrderData> getShippedOrdersByWorkspace(String workspaceId) {
    return getOrdersByWorkspace(workspaceId)
        .where((order) =>
    order.packingStatus == PackingStatus.sudahDikirim)
        .toList();
  }

  /// ==========================================================
  /// BUKA KEMBALI ORDER
  /// ==========================================================

  bool reopenKeeperWork({
    required String orderId,
    required String workspaceId,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (order.paymentStatus == PaymentStatus.sudahDibayar) {
      return false;
    }
    if (order.keeperStage != KeeperStage.selesaiDikerjakan) {
      return false;
    }

    order.keeperStage = KeeperStage.sedangDikerjakan;
    order.status = OrderStatus.belumSelesai;
    order.completedAt = null;
    order.packingStatus = PackingStatus.belumDipacking;
    order.packedAt = null;
    order.shippedAt = null;
    order.receiptPrintedAt = null;

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// FINALISASI PEMBAYARAN
  /// ==========================================================
  ///
  /// HANYA ADMIN FINANCE yang nantinya boleh memanggil fungsi
  /// ini.
  ///
  /// Aturan keamanan:
  ///
  /// 1. Order harus ditemukan.
  /// 2. Workspace harus cocok.
  /// 3. Order harus SELESAI.
  /// 4. Payment status harus BELUM DIBAYAR.
  /// 5. completedAt harus ada.
  /// 6. paidAt harus null.
  /// 7. Harga harus lebih dari 0.
  ///
  /// Jika salah satu syarat gagal:
  /// pembayaran DITOLAK.
  ///
  /// Fungsi mengembalikan true jika berhasil.
  bool markAsPaid({
    required String orderId,
    required String workspaceId,
    DateTime? paymentDate,
  }) {
    final int index = _orders.indexWhere(
          (order) => order.id == orderId,
    );

    if (index == -1) {
      return false;
    }

    final OrderData order = _orders[index];

    /// --------------------------------------------------------
    /// VALIDASI WORKSPACE
    /// --------------------------------------------------------

    if (order.workspaceId != workspaceId) {
      return false;
    }

    /// --------------------------------------------------------
    /// VALIDASI STATUS PRODUKSI
    /// --------------------------------------------------------

    if (order.status != OrderStatus.selesai) {
      return false;
    }

    /// --------------------------------------------------------
    /// VALIDASI STATUS PEMBAYARAN
    /// --------------------------------------------------------

    if (order.paymentStatus != PaymentStatus.belumDibayar) {
      return false;
    }

    /// --------------------------------------------------------
    /// VALIDASI TIMESTAMP KEEPER
    /// --------------------------------------------------------

    if (order.completedAt == null) {
      return false;
    }

    /// --------------------------------------------------------
    /// ANTI DOUBLE PAYMENT
    /// --------------------------------------------------------

    if (order.paidAt != null) {
      return false;
    }

    /// --------------------------------------------------------
    /// VALIDASI NOMINAL
    /// --------------------------------------------------------

    if (order.price <= 0) {
      return false;
    }

    /// --------------------------------------------------------
    /// FINALISASI
    /// --------------------------------------------------------

    order.paymentStatus = PaymentStatus.sudahDibayar;

    order.paidAt = paymentDate ?? DateTime.now();

    /// createdAt TETAP.
    /// completedAt TETAP.
    /// price TETAP.
    ///
    /// Tidak ada nilai order yang ditimpa.

    notifyListeners();
    unawaited(_persistOrder(order));

    return true;
  }

  /// ==========================================================
  /// EDIT ORDER OLEH ADMIN
  /// ==========================================================
  ///
  /// Dipakai khusus menu Edit Order Admin.
  /// Semua perubahan tetap berada pada OrderData yang sama sehingga
  /// ID dan createdAt tidak berubah.
  ///
  /// Admin memiliki hak penuh mengubah data order.
  /// Jika order sudah DIBAYAR, PaymentRecord di Finance tetap menjadi
  /// snapshot audit pembayaran dan tidak ikut diubah oleh edit ini.
  bool adminEditOrder({
    required String orderId,
    required String workspaceId,
    required String productName,
    required String ukuran,
    required String frame,
    required int price,
    required int deadlineDays,
    required String catatan,
    Uint8List? productImage,
    String? productImageFileName,
    String? productImageUrl,
    String? shippingCourier,
    Uint8List? shippingReceiptImage,
    String? shippingReceiptFileName,
    String? shippingReceiptUrl,
    DateTime? shippingDate,
    bool replaceProductImage = false,
    bool replaceShippingReceipt = false,
    bool? requiresReceiptBeforeWork,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    if (productName.trim().isEmpty || ukuran.trim().isEmpty) return false;
    if (frame.trim().isEmpty || price <= 0 || deadlineDays <= 0) return false;

    order.productName = productName.trim();
    order.ukuran = ukuran.trim();
    order.frame = frame.trim();
    order.price = price;
    order.deadlineDays = deadlineDays;
    order.catatan = catatan.trim();

    if (requiresReceiptBeforeWork != null) {
      order.requiresReceiptBeforeWork = requiresReceiptBeforeWork;
    }

    if (replaceProductImage) {
      order.productImage = productImage;
      order.productImageFileName = productImageFileName;
      order.productImageUrl = productImageUrl;
    }

    if (replaceShippingReceipt) {
      order.shippingCourier = shippingCourier?.trim();
      order.shippingReceiptImage = shippingReceiptImage;
      order.shippingReceiptFileName = shippingReceiptFileName;
      order.shippingReceiptUrl = shippingReceiptUrl;
      order.shippingDate = shippingDate;
    }

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// KONTROL STATUS OLEH ADMIN
  /// ==========================================================
  ///
  /// Admin dapat:
  /// - mengembalikan SELESAI -> BELUM SELESAI
  /// - menyelesaikan order yang masih proses
  /// - mengubah ke SIAP DIKIRIM bila diperlukan
  ///
  /// Admin adalah otoritas kontrol flow produksi. Status dapat diubah
  /// ke BELUM SELESAI, SIAP DIKIRIM, atau SELESAI kapan pun.
  bool adminUpdateStatus({
    required String orderId,
    required String workspaceId,
    required OrderStatus newStatus,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;


    order.status = newStatus;

    // Admin tetap menjadi otoritas status produksi, tetapi posisi Keeper
    // harus ikut tersinkron agar tidak ada dua status yang berbeda.
    final now = DateTime.now();

    if (newStatus == OrderStatus.selesai) {
      order.startedAt ??= now;
      order.keeperStage = KeeperStage.selesaiDikerjakan;
      order.completedAt ??= now;
    } else if (newStatus == OrderStatus.siapDikirim) {
      order.startedAt ??= now;
      order.keeperStage = KeeperStage.inputResi;
      order.readyToShipAt ??= now;
      order.completedAt = null;
    } else {
      if (order.keeperStage == KeeperStage.selesaiDikerjakan) {
        order.keeperStage = KeeperStage.sedangDikerjakan;
      }
      order.startedAt ??= now;
      order.completedAt = null;
      order.packingStatus = PackingStatus.belumDipacking;
      order.packedAt = null;
      order.shippedAt = null;
    }

    notifyListeners();
    unawaited(_persistOrder(order));
    return true;
  }

  /// ==========================================================
  /// HAPUS ORDER OLEH ADMIN
  /// ==========================================================
  ///
  /// Workspace wajib cocok.
  /// Admin boleh menghapus order pada status apa pun. Jika order sudah
  /// dibayar, PaymentRecord Finance tetap dipertahankan sebagai histori audit.
  bool adminRemoveOrder({
    required String orderId,
    required String workspaceId,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;

    final order = _orders[index];
    if (order.workspaceId != workspaceId) return false;
    _orders.removeAt(index);
    notifyListeners();
    unawaited(_repository.deleteOrder(
      orderId: orderId,
      workspaceId: workspaceId,
    ).catchError((error) {
      debugPrint('SUPABASE DELETE ORDER GAGAL: $error');
    }));
    return true;
  }

  /// ==========================================================
  /// GLOBAL DELETE ORDER OLEH ADMIN
  /// ==========================================================
  ///
  /// Penghapusan dilakukan database-first.
  ///
  /// Aturan keamanan:
  /// - Semua order harus berada di workspace yang sama dengan workspaceId.
  /// - Order hanya dihapus dari memory setelah DELETE Supabase berhasil.
  /// - Setelah memory berubah, seluruh UI yang mendengarkan OrderStore
  ///   akan ikut memperbarui tampilan melalui notifyListeners().
  ///
  /// Payment audit tidak disentuh oleh fungsi ini.
  Future<List<String>> adminDeleteOrdersGlobal({
    required List<String> orderIds,
    required String workspaceId,
  }) async {
    if (orderIds.isEmpty) return <String>[];

    final requestedIds = orderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (requestedIds.isEmpty) return <String>[];

    // Kunci workspace: hanya order milik workspace aktif yang boleh diproses.
    final removable = _orders
        .where(
          (order) =>
      requestedIds.contains(order.id) &&
          order.workspaceId == workspaceId,
    )
        .toList();

    if (removable.isEmpty) return <String>[];

    final deletedIds = <String>[];

    // Database-first: jangan menghapus dari memory sebelum DELETE Supabase
    // benar-benar berhasil.
    for (final order in removable) {
      await _repository.deleteOrder(
        orderId: order.id,
        workspaceId: workspaceId,
      );
      deletedIds.add(order.id);
    }

    if (deletedIds.isNotEmpty) {
      _orders.removeWhere((order) => deletedIds.contains(order.id));
      notifyListeners();
    }

    return deletedIds;
  }

  /// ==========================================================
  /// CARI ORDER BERDASARKAN ID
  /// ==========================================================

  OrderData? getOrderById(String orderId) {
    try {
      return _orders.firstWhere(
            (order) => order.id == orderId,
      );
    } catch (_) {
      return null;
    }
  }

  /// ==========================================================
  /// CARI ORDER BERDASARKAN WORKSPACE
  /// ==========================================================

  List<OrderData> getOrdersByWorkspace(
      String workspaceId,
      ) {
    return _orders
        .where(
          (order) => order.workspaceId == workspaceId,
    )
        .toList();
  }

  /// ==========================================================
  /// ORDER BERDASARKAN TAHAP KEEPER
  /// ==========================================================

  List<OrderData> getOrdersByKeeperStage(
      String workspaceId,
      KeeperStage stage,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where((order) => order.keeperStage == stage)
        .toList();
  }

  List<OrderData> getKeeperIncomingOrders(String workspaceId) =>
      getOrdersByKeeperStage(workspaceId, KeeperStage.orderanMasuk);

  List<OrderData> getKeeperWorkingOrders(String workspaceId) =>
      getOrdersByKeeperStage(workspaceId, KeeperStage.sedangDikerjakan);

  List<OrderData> getKeeperReceiptOrders(String workspaceId) =>
      getOrdersByKeeperStage(workspaceId, KeeperStage.inputResi);

  List<OrderData> getKeeperFinishedOrders(String workspaceId) =>
      getOrdersByKeeperStage(workspaceId, KeeperStage.selesaiDikerjakan);

  /// ==========================================================
  /// ORDER LAYAK DIBAYAR
  /// ==========================================================
  ///
  /// Hanya mengembalikan:
  ///
  /// workspace benar
  /// +
  /// SELESAI
  /// +
  /// BELUM DIBAYAR
  /// +
  /// completedAt tersedia
  /// +
  /// paidAt null
  /// +
  /// harga valid
  ///
  List<OrderData> getEligibleOrdersForPayment(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) => order.isEligibleForPayment,
    )
        .toList();
  }

  /// ==========================================================
  /// ORDER SUDAH DIBAYAR
  /// ==========================================================

  List<OrderData> getPaidOrdersByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) =>
      order.paymentStatus ==
          PaymentStatus.sudahDibayar,
    )
        .toList();
  }

  /// ==========================================================
  /// ORDER BELUM DIBAYAR
  /// ==========================================================

  List<OrderData> getUnpaidOrdersByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) =>
      order.paymentStatus ==
          PaymentStatus.belumDibayar,
    )
        .toList();
  }

  /// ==========================================================
  /// TOTAL NOMINAL WORKSPACE
  /// ==========================================================

  int getTotalByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId).fold(
      0,
          (total, order) => total + order.price,
    );
  }

  /// ==========================================================
  /// TOTAL NOMINAL ORDER BELUM SELESAI
  /// ==========================================================
  ///
  /// Yang masih belum selesai mencakup:
  ///
  /// - belumSelesai
  /// - siapDikirim
  ///
  /// Karena siap dikirim belum masuk status SELESAI.
  int getUnfinishedTotalByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) => order.status != OrderStatus.selesai,
    )
        .fold(
      0,
          (total, order) => total + order.price,
    );
  }

  /// ==========================================================
  /// TOTAL NOMINAL ORDER SELESAI
  /// ==========================================================

  int getFinishedTotalByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) => order.status == OrderStatus.selesai,
    )
        .fold(
      0,
          (total, order) => total + order.price,
    );
  }

  /// ==========================================================
  /// TOTAL NOMINAL MENUNGGU PEMBAYARAN
  /// ==========================================================

  int getUnpaidTotalByWorkspace(
      String workspaceId,
      ) {
    return getEligibleOrdersForPayment(workspaceId).fold(
      0,
          (total, order) => total + order.price,
    );
  }

  /// ==========================================================
  /// TOTAL NOMINAL SUDAH DIBAYAR
  /// ==========================================================

  int getPaidTotalByWorkspace(
      String workspaceId,
      ) {
    return getPaidOrdersByWorkspace(workspaceId).fold(
      0,
          (total, order) => total + order.price,
    );
  }

  /// ==========================================================
  /// JUMLAH ORDER WORKSPACE
  /// ==========================================================

  int getOrderCountByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId).length;
  }

  /// ==========================================================
  /// JUMLAH ORDER BELUM SELESAI
  /// ==========================================================

  int getUnfinishedCountByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) => order.status != OrderStatus.selesai,
    )
        .length;
  }

  /// ==========================================================
  /// JUMLAH ORDER SELESAI
  /// ==========================================================

  int getFinishedCountByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId)
        .where(
          (order) => order.status == OrderStatus.selesai,
    )
        .length;
  }

  /// ==========================================================
  /// JUMLAH MENUNGGU PEMBAYARAN
  /// ==========================================================

  int getUnpaidCountByWorkspace(
      String workspaceId,
      ) {
    return getEligibleOrdersForPayment(workspaceId).length;
  }

  /// ==========================================================
  /// JUMLAH SUDAH DIBAYAR
  /// ==========================================================

  int getPaidCountByWorkspace(
      String workspaceId,
      ) {
    return getPaidOrdersByWorkspace(workspaceId).length;
  }

  /// ==========================================================
  /// ORDER TERBARU WORKSPACE
  /// ==========================================================

  List<OrderData> getLatestOrdersByWorkspace(
      String workspaceId,
      ) {
    return getOrdersByWorkspace(workspaceId);
  }

  /// ==========================================================
  /// SIMPAN PERUBAHAN ORDER KE SUPABASE
  /// ==========================================================
  ///
  /// Method ini sengaja fire-and-forget agar seluruh method OrderStore
  /// tetap sinkron dan tidak memaksa perubahan besar pada UI lama.
  Future<void> _persistOrder(OrderData order) async {
    try {
      final savedOrder = await _repository.updateOrder(order);
      final index = _orders.indexWhere((item) => item.id == savedOrder.id);
      if (index == -1) return;

      _orders[index] = savedOrder;
      notifyListeners();
    } catch (error) {
      debugPrint('SUPABASE UPDATE ORDER GAGAL: $error');
    }
  }

  /// ==========================================================
  /// HAPUS ORDER
  /// ==========================================================
  ///
  /// CATATAN:
  /// Fungsi ini adalah penghapusan ORDER PRODUKSI.
  ///
  /// Jangan gunakan fungsi ini untuk cleanup pembayaran.
  ///
  /// Payment cleanup nantinya harus mempunyai mekanisme sendiri
  /// sehingga riwayat produksi/order tidak ikut terhapus.
  void removeOrder(String orderId) {
    OrderData? removedOrder;

    for (final order in _orders) {
      if (order.id == orderId) {
        removedOrder = order;
        break;
      }
    }

    _orders.removeWhere(
          (order) => order.id == orderId,
    );

    notifyListeners();

    if (removedOrder != null) {
      unawaited(_repository.deleteOrder(
        orderId: removedOrder.id,
        workspaceId: removedOrder.workspaceId,
      ).catchError((error) {
        debugPrint('SUPABASE DELETE ORDER GAGAL: $error');
      }));
    }
  }

  /// ==========================================================
  /// CLEAR DATA
  /// ==========================================================
  ///
  /// Untuk testing/development.
  void clear() {
    _orders.clear();
    notifyListeners();
  }
}
