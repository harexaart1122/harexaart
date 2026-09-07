import 'dart:typed_data';

import '../../../data/order_store.dart';

/// ============================================================
/// PAYMENT RECORD
/// ============================================================
///
/// PaymentRecord adalah representasi data pembayaran dari OrderData.
///
/// PENTING:
/// - Harga TIDAK dibuat ulang di Finance.
/// - amount selalu berasal dari OrderData.price.
/// - Workspace tetap mengikuti OrderData.workspaceId.
/// - Tanggal order, selesai Keeper, dan pembayaran Admin
///   disimpan terpisah.
///
class PaymentRecord {
  final String paymentId;

  final String orderId;

  final String workspaceId;

  final String workspaceName;

  final String productName;

  final String ukuran;

  final String frame;

  /// Nominal pembayaran.
  ///
  /// Nilai ini HARUS berasal dari harga final Input Order.
  final int amount;

  /// Foto produk.
  ///
  /// Saat ini dapat berasal langsung dari memory OrderStore.
  final Uint8List? productImage;

  /// Nama file foto produk.
  final String? productImageFileName;

  /// URL foto jika nanti Supabase/Storage sudah aktif.
  final String? productImageUrl;

  /// Waktu Input Order.
  final DateTime orderCreatedAt;

  /// Waktu Keeper menekan SELESAI REAL.
  final DateTime? completedAt;

  /// Waktu Admin melakukan pembayaran.
  final DateTime? paidAt;

  /// Status pembayaran.
  final PaymentStatus paymentStatus;

  /// Status produksi/order.
  final OrderStatus orderStatus;

  const PaymentRecord({
    required this.paymentId,
    required this.orderId,
    required this.workspaceId,
    required this.workspaceName,
    required this.productName,
    required this.ukuran,
    required this.frame,
    required this.amount,
    required this.orderCreatedAt,
    required this.paymentStatus,
    required this.orderStatus,
    this.productImage,
    this.productImageFileName,
    this.productImageUrl,
    this.completedAt,
    this.paidAt,
  });

  /// ==========================================================
  /// DARI ORDER DATA
  /// ==========================================================
  ///
  /// Ini adalah jalur utama:
  ///
  /// Input Order
  ///      ↓
  /// OrderData
  ///      ↓
  /// PaymentRecord
  ///
  factory PaymentRecord.fromOrder(OrderData order) {
    return PaymentRecord(
      paymentId: 'PAY-${order.id}',
      orderId: order.id,
      workspaceId: order.workspaceId,
      workspaceName: order.workspaceName,
      productName: order.productName,
      ukuran: order.ukuran,
      frame: order.frame,
      amount: order.price,
      productImage: order.productImage,
      productImageFileName: order.productImageFileName,
      productImageUrl: order.productImageUrl,
      orderCreatedAt: order.createdAt,
      completedAt: order.completedAt,
      paidAt: order.paidAt,
      paymentStatus: order.paymentStatus,
      orderStatus: order.status,
    );
  }

  /// ==========================================================
  /// STATUS
  /// ==========================================================

  bool get isCompleted {
    return orderStatus == OrderStatus.selesai;
  }

  bool get isPaid {
    return paymentStatus == PaymentStatus.sudahDibayar;
  }

  bool get isUnpaid {
    return paymentStatus == PaymentStatus.belumDibayar;
  }

  /// ==========================================================
  /// BOLEH DIBAYAR
  /// ==========================================================
  ///
  /// Syarat:
  /// 1. Order selesai.
  /// 2. Belum dibayar.
  /// 3. Ada completedAt.
  /// 4. Belum ada paidAt.
  /// 5. Nominal > 0.
  ///
  bool get isEligibleForPayment {
    return isCompleted &&
        isUnpaid &&
        completedAt != null &&
        paidAt == null &&
        amount > 0;
  }

  /// ==========================================================
  /// VALIDASI WORKSPACE
  /// ==========================================================

  bool isValidForWorkspace(String expectedWorkspaceId) {
    return workspaceId == expectedWorkspaceId;
  }

  /// ==========================================================
  /// VALIDASI PEMBAYARAN
  /// ==========================================================

  bool isValidForPayment(String expectedWorkspaceId) {
    return isValidForWorkspace(expectedWorkspaceId) &&
        isEligibleForPayment;
  }

  /// ==========================================================
  /// COPY WITH
  /// ==========================================================

  PaymentRecord copyWith({
    String? paymentId,
    String? orderId,
    String? workspaceId,
    String? workspaceName,
    String? productName,
    String? ukuran,
    String? frame,
    int? amount,
    Uint8List? productImage,
    String? productImageFileName,
    String? productImageUrl,
    DateTime? orderCreatedAt,
    DateTime? completedAt,
    DateTime? paidAt,
    PaymentStatus? paymentStatus,
    OrderStatus? orderStatus,
  }) {
    return PaymentRecord(
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      workspaceId: workspaceId ?? this.workspaceId,
      workspaceName: workspaceName ?? this.workspaceName,
      productName: productName ?? this.productName,
      ukuran: ukuran ?? this.ukuran,
      frame: frame ?? this.frame,
      amount: amount ?? this.amount,
      productImage: productImage ?? this.productImage,
      productImageFileName:
      productImageFileName ?? this.productImageFileName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      orderCreatedAt: orderCreatedAt ?? this.orderCreatedAt,
      completedAt: completedAt ?? this.completedAt,
      paidAt: paidAt ?? this.paidAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderStatus: orderStatus ?? this.orderStatus,
    );
  }

  /// ==========================================================
  /// MARK AS PAID
  /// ==========================================================

  PaymentRecord markPaid({
    DateTime? paymentDate,
  }) {
    return copyWith(
      paymentStatus: PaymentStatus.sudahDibayar,
      paidAt: paymentDate ?? DateTime.now(),
    );
  }
}