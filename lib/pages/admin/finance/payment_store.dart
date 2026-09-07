import 'package:flutter/foundation.dart';

import '../../../data/order_store.dart';
import 'payment_model.dart';

/// ============================================================================
/// HAREXAART - PAYMENT STORE
/// ============================================================================
///
/// PaymentStore adalah penyimpanan AUDIT untuk pembayaran yang sudah
/// benar-benar difinalisasi oleh OrderStore.
///
/// SUMBER KEBENARAN:
///   OrderData / OrderStore
///          ↓
///   OrderStore.markAsPaid()
///          ↓
///   PaymentStore.addPaymentFromOrder()
///          ↓
///   Riwayat pembayaran / laporan Finance
///
/// ATURAN PENTING:
/// - PaymentStore TIDAK memfinalisasi pembayaran.
/// - PaymentStore TIDAK mengubah harga order.
/// - PaymentStore TIDAK mengubah createdAt.
/// - PaymentStore TIDAK mengubah completedAt.
/// - PaymentStore TIDAK menghapus order produksi.
/// - Hanya order yang sudah SELESAI + SUDAH DIBAYAR yang boleh masuk audit.
/// - Workspace harus cocok.
/// - Satu order hanya boleh mempunyai satu audit payment record.
/// - Jika audit sudah ada, proses sinkronisasi bersifat idempotent.
/// ============================================================================

class PaymentStore extends ChangeNotifier {
  PaymentStore._internal();

  static final PaymentStore instance = PaymentStore._internal();

  /// Snapshot audit pembayaran.
  ///
  /// Jangan expose list internal secara mutable.
  final List<PaymentRecord> _payments = <PaymentRecord>[];

  /// Semua record audit pembayaran.
  List<PaymentRecord> get payments =>
      List<PaymentRecord>.unmodifiable(_payments);

  /// Alias yang lebih eksplisit untuk kebutuhan Finance/report.
  List<PaymentRecord> get allPayments =>
      List<PaymentRecord>.unmodifiable(_payments);

  /// ==========================================================================
  /// GET PAYMENT BY ID
  /// ==========================================================================

  PaymentRecord? getPaymentById(String paymentId) {
    final String id = paymentId.trim();
    if (id.isEmpty) {
      return null;
    }

    for (final PaymentRecord payment in _payments) {
      if (payment.paymentId == id) {
        return payment;
      }
    }

    return null;
  }

  /// ==========================================================================
  /// GET PAYMENT BY ORDER ID
  /// ==========================================================================
  ///
  /// Satu order hanya boleh memiliki satu audit pembayaran.

  PaymentRecord? getPaymentByOrderId(String orderId) {
    final String id = orderId.trim();
    if (id.isEmpty) {
      return null;
    }

    for (final PaymentRecord payment in _payments) {
      if (payment.orderId == id) {
        return payment;
      }
    }

    return null;
  }

  /// ==========================================================================
  /// GET PAID PAYMENTS BY WORKSPACE
  /// ==========================================================================
  ///
  /// Finance memakai method ini untuk tab "Sudah Dibayar".
  /// Data workspace lain tidak boleh ikut keluar.

  List<PaymentRecord> getPaidPaymentsByWorkspace(String workspaceId) {
    final String id = workspaceId.trim();

    if (id.isEmpty) {
      return <PaymentRecord>[];
    }

    final List<PaymentRecord> result = _payments
        .where(
          (PaymentRecord payment) =>
      payment.workspaceId == id &&
          payment.isCompleted &&
          payment.isPaid &&
          payment.paidAt != null,
    )
        .toList();

    result.sort((PaymentRecord a, PaymentRecord b) {
      final DateTime aDate = a.paidAt ?? a.orderCreatedAt;
      final DateTime bDate = b.paidAt ?? b.orderCreatedAt;
      return bDate.compareTo(aDate);
    });

    return List<PaymentRecord>.unmodifiable(result);
  }

  /// ==========================================================================
  /// VALIDASI ORDER UNTUK AUDIT PAYMENT
  /// ==========================================================================
  ///
  /// PaymentStore hanya menerima snapshot setelah OrderStore benar-benar
  /// menyatakan order sudah dibayar.

  bool _isValidFinalizedOrder(OrderData order) {
    if (order.id.trim().isEmpty) {
      return false;
    }

    if (order.workspaceId.trim().isEmpty) {
      return false;
    }

    if (order.status != OrderStatus.selesai) {
      return false;
    }

    if (order.paymentStatus != PaymentStatus.sudahDibayar) {
      return false;
    }

    if (order.completedAt == null) {
      return false;
    }

    if (order.paidAt == null) {
      return false;
    }

    if (order.price <= 0) {
      return false;
    }

    return true;
  }

  /// ==========================================================================
  /// ADD PAYMENT FROM ORDER
  /// ==========================================================================
  ///
  /// Dipanggil setelah:
  ///
  ///   OrderStore.markAsPaid(...)
  ///
  /// berhasil.
  ///
  /// Fungsi ini idempotent berdasarkan orderId.
  /// Jika audit untuk order sudah ada, fungsi mengembalikan true tanpa
  /// membuat duplikat dan tanpa menimpa snapshot audit lama.

  bool addPaymentFromOrder(OrderData order) {
    if (!_isValidFinalizedOrder(order)) {
      return false;
    }

    final String orderId = order.id.trim();
    final PaymentRecord? existing = getPaymentByOrderId(orderId);

    if (existing != null) {
      // Audit sudah tersimpan. Jangan membuat duplikat.
      return true;
    }

    final PaymentRecord payment = PaymentRecord.fromOrder(order);

    // Final safety check terhadap record hasil mapping.
    if (payment.orderId.trim().isEmpty) {
      return false;
    }

    if (payment.workspaceId != order.workspaceId) {
      return false;
    }

    if (!payment.isCompleted || !payment.isPaid) {
      return false;
    }

    if (payment.completedAt == null || payment.paidAt == null) {
      return false;
    }

    if (payment.amount <= 0) {
      return false;
    }

    _payments.add(payment);
    _sortPaymentsNewestFirst();
    notifyListeners();

    return true;
  }

  /// ==========================================================================
  /// SYNC PAID ORDERS FROM ORDER STORE
  /// ==========================================================================
  ///
  /// Dipakai ketika Finance dibuka atau ketika OrderStore berubah.
  ///
  /// Tujuan utamanya adalah memastikan pembayaran yang sudah finalized di
  /// OrderStore masuk ke PaymentStore sebagai audit, tanpa duplikasi.
  ///
  /// Return value = jumlah audit record baru yang berhasil ditambahkan.

  int syncPaidOrdersFromOrderStore(String workspaceId) {
    final String id = workspaceId.trim();

    if (id.isEmpty) {
      return 0;
    }

    final List<OrderData> orders = OrderStore.instance.getOrdersByWorkspace(id);

    int addedCount = 0;

    for (final OrderData order in orders) {
      if (order.workspaceId != id) {
        continue;
      }

      if (!_isValidFinalizedOrder(order)) {
        continue;
      }

      final bool alreadyExists = _payments.any(
            (PaymentRecord payment) => payment.orderId == order.id,
      );

      if (alreadyExists) {
        continue;
      }

      final PaymentRecord payment = PaymentRecord.fromOrder(order);

      if (payment.workspaceId != id) {
        continue;
      }

      if (!payment.isCompleted || !payment.isPaid) {
        continue;
      }

      if (payment.completedAt == null || payment.paidAt == null) {
        continue;
      }

      if (payment.amount <= 0) {
        continue;
      }

      _payments.add(payment);
      addedCount++;
    }

    if (addedCount > 0) {
      _sortPaymentsNewestFirst();
      notifyListeners();
    }

    return addedCount;
  }

  /// ==========================================================================
  /// SYNC ALL WORKSPACES
  /// ==========================================================================
  ///
  /// Dipakai bila nantinya dashboard Finance memerlukan refresh audit untuk
  /// seluruh workspace yang tersedia.
  ///
  /// Karena OrderStore menjadi sumber kebenaran, method ini tidak membuat
  /// pembayaran baru dan tidak mengubah order apa pun.

  int syncAllPaidOrdersFromOrderStore() {
    final List<OrderData> orders = OrderStore.instance.orders;
    int addedCount = 0;

    for (final OrderData order in orders) {
      if (!_isValidFinalizedOrder(order)) {
        continue;
      }

      final bool alreadyExists = _payments.any(
            (PaymentRecord payment) => payment.orderId == order.id,
      );

      if (alreadyExists) {
        continue;
      }

      final PaymentRecord payment = PaymentRecord.fromOrder(order);

      if (payment.workspaceId != order.workspaceId) {
        continue;
      }

      if (!payment.isCompleted || !payment.isPaid) {
        continue;
      }

      if (payment.completedAt == null || payment.paidAt == null) {
        continue;
      }

      if (payment.amount <= 0) {
        continue;
      }

      _payments.add(payment);
      addedCount++;
    }

    if (addedCount > 0) {
      _sortPaymentsNewestFirst();
      notifyListeners();
    }

    return addedCount;
  }

  /// ==========================================================================
  /// PAYMENT COUNTS
  /// ==========================================================================

  int get totalPaymentCount => _payments.length;

  int get totalPaidCount => _payments
      .where(
        (PaymentRecord payment) =>
    payment.isCompleted && payment.isPaid && payment.paidAt != null,
  )
      .length;

  int get totalPaidAmount => _payments.fold<int>(
    0,
        (int total, PaymentRecord payment) => total + payment.amount,
  );

  int getPaidCountByWorkspace(String workspaceId) {
    return getPaidPaymentsByWorkspace(workspaceId).length;
  }

  int getPaidAmountByWorkspace(String workspaceId) {
    return getPaidPaymentsByWorkspace(workspaceId).fold<int>(
      0,
          (int total, PaymentRecord payment) => total + payment.amount,
    );
  }

  /// ==========================================================================
  /// INTERNAL SORT
  /// ==========================================================================

  void _sortPaymentsNewestFirst() {
    _payments.sort((PaymentRecord a, PaymentRecord b) {
      final DateTime aDate = a.paidAt ?? a.orderCreatedAt;
      final DateTime bDate = b.paidAt ?? b.orderCreatedAt;
      return bDate.compareTo(aDate);
    });
  }
}
