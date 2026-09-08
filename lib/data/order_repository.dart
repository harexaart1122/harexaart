import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_store.dart';

/// ============================================================
/// ORDER REPOSITORY
/// ============================================================
///
/// Jembatan antara OrderStore dan Supabase.
///
/// OrderData tetap berada di order_store.dart.
/// OrderStore belum diubah.
/// ============================================================

class OrderRepository {
  final SupabaseClient _client;

  OrderRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  static const String tableName = 'orders';

  // Supabase Storage untuk file order.
  static const String productImageBucket = 'product-images';
  static const String shippingReceiptBucket = 'shipping-receipts';

  /// ==========================================================
  /// FETCH SEMUA ORDER
  /// ==========================================================

  Future<List<OrderData>> fetchOrders() async {
    final response = await _client
        .from(tableName)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (row) {
        final order = OrderDataMapper.fromSupabaseMap(
          Map<String, dynamic>.from(row as Map),
        );

        if (order.productImageUrl == null &&
            order.productImageFileName != null) {
          return order.copyWith(
            productImageUrl: productImageUrlFallback(
              order.productImageFileName,
            ),
          );
        }

        return order;
      },
    )
        .toList();
  }

  /// ==========================================================
  /// FETCH ORDER BERDASARKAN WORKSPACE
  /// ==========================================================

  Future<List<OrderData>> fetchOrdersByWorkspace(
      String workspaceId,
      ) async {
    final response = await _client
        .from(tableName)
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (row) {
        final order = OrderDataMapper.fromSupabaseMap(
          Map<String, dynamic>.from(row as Map),
        );

        if (order.productImageUrl == null &&
            order.productImageFileName != null) {
          return order.copyWith(
            productImageUrl: productImageUrlFallback(
              order.productImageFileName,
            ),
          );
        }

        return order;
      },
    )
        .toList();
  }

  /// ==========================================================
  /// FETCH SATU ORDER
  /// ==========================================================

  Future<OrderData?> fetchOrderById(
      String orderId,
      ) async {
    final response = await _client
        .from(tableName)
        .select()
        .eq('id', orderId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// INSERT ORDER
  /// ==========================================================

  Future<OrderData> insertOrder(
      OrderData order,
      ) async {
    var orderToSave = order;

    // Jika Input Order membawa bytes gambar, upload dulu ke Storage.
    // URL hasil upload kemudian disimpan bersama data order.
    if (order.productImage != null &&
        order.productImageFileName != null &&
        order.productImageFileName!.trim().isNotEmpty) {
      final imageUrl = await uploadProductImage(
        order: order,
      );

      orderToSave = orderToSave.copyWith(
        productImageUrl: imageUrl,
      );
    }

    // Jika Input Order membawa bytes resi, upload PDF/foto resi
    // ke bucket shipping-receipts sebelum row order dibuat.
    if (order.shippingReceiptImage != null &&
        order.shippingReceiptFileName != null &&
        order.shippingReceiptFileName!.trim().isNotEmpty) {
      final receiptUrl = await uploadShippingReceipt(
        order: orderToSave,
      );

      orderToSave = orderToSave.copyWith(
        shippingReceiptUrl: receiptUrl,
      );
    }

    final response = await _client
        .from(tableName)
        .insert(orderToSave.toSupabaseMap())
        .select()
        .single();

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// UPLOAD GAMBAR PRODUK KE SUPABASE STORAGE
  /// ==========================================================

  Future<String> uploadProductImage({
    required OrderData order,
  }) async {
    final bytes = order.productImage;
    final fileName = order.productImageFileName?.trim();

    if (bytes == null || bytes.isEmpty) {
      throw StateError('Bytes gambar produk kosong.');
    }

    if (fileName == null || fileName.isEmpty) {
      throw StateError('Nama file gambar produk kosong.');
    }

    final safeFileName = _safeStorageFileName(fileName);
    final storagePath =
        '${order.workspaceId}/${order.id}/$safeFileName';

    await _client.storage.from(productImageBucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _imageContentType(fileName),
        upsert: true,
      ),
    );

    return _client.storage
        .from(productImageBucket)
        .getPublicUrl(storagePath);
  }

  /// URL fallback untuk file lama yang sudah ada di root bucket.
  /// Ini membantu order lama seperti 1.png tanpa upload ulang.
  String? productImageUrlFallback(String? fileName) {
    final name = fileName?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }

    return _client.storage
        .from(productImageBucket)
        .getPublicUrl(name);
  }

  /// ==========================================================
  /// UPLOAD RESI KE SUPABASE STORAGE
  /// ==========================================================

  Future<String> uploadShippingReceipt({
    required OrderData order,
  }) async {
    final bytes = order.shippingReceiptImage;
    final fileName = order.shippingReceiptFileName?.trim();

    if (bytes == null || bytes.isEmpty) {
      throw StateError('Bytes resi kosong.');
    }

    if (fileName == null || fileName.isEmpty) {
      throw StateError('Nama file resi kosong.');
    }

    final safeFileName = _safeStorageFileName(fileName);
    final storagePath =
        '${order.workspaceId}/${order.id}/$safeFileName';

    await _client.storage.from(shippingReceiptBucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _receiptContentType(fileName),
        upsert: true,
      ),
    );

    return _client.storage
        .from(shippingReceiptBucket)
        .getPublicUrl(storagePath);
  }

  static String _receiptContentType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';

    return 'image/jpeg';
  }

  static String _safeStorageFileName(String fileName) {
    final extension = _storageExtension(fileName);

    // Jangan gunakan nama file asli sebagai object key Storage.
    // Beberapa browser/device dapat menghasilkan nama file dengan
    // karakter yang ditolak Supabase Storage (contoh: "~").
    // Nama asli tetap disimpan di kolom database.
    return 'file_${DateTime.now().microsecondsSinceEpoch}$extension';
  }

  static String _storageExtension(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.pdf')) return '.pdf';
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.bmp')) return '.bmp';
    if (lower.endsWith('.svg')) return '.svg';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg';

    return '.jpg';
  }

  static String _imageContentType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';

    return 'image/jpeg';
  }

  /// ==========================================================
  /// UPDATE ORDER
  /// ==========================================================

  Future<OrderData> updateOrder(
      OrderData order,
      ) async {
    var orderToSave = order;

    // Upload hanya saat ada bytes baru tetapi URL belum tersedia.
    // Jadi perubahan status biasa tidak meng-upload ulang file.
    if (order.productImage != null &&
        order.productImageFileName != null &&
        order.productImageFileName!.trim().isNotEmpty &&
        (order.productImageUrl == null ||
            order.productImageUrl!.trim().isEmpty)) {
      final imageUrl = await uploadProductImage(order: orderToSave);
      orderToSave = orderToSave.copyWith(
        productImageUrl: imageUrl,
      );
    }

    if (order.shippingReceiptImage != null &&
        order.shippingReceiptFileName != null &&
        order.shippingReceiptFileName!.trim().isNotEmpty &&
        (order.shippingReceiptUrl == null ||
            order.shippingReceiptUrl!.trim().isEmpty)) {
      final receiptUrl = await uploadShippingReceipt(order: orderToSave);
      orderToSave = orderToSave.copyWith(
        shippingReceiptUrl: receiptUrl,
      );
    }

    final response = await _client
        .from(tableName)
        .update(orderToSave.toSupabaseMap())
        .eq('id', order.id)
        .eq('workspace_id', order.workspaceId)
        .select()
        .single();

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// UPDATE STATUS PRODUKSI
  /// ==========================================================

  Future<OrderData?> updateProductionStatus({
    required String orderId,
    required String workspaceId,
    required OrderStatus status,
    DateTime? startedAt,
    DateTime? readyToShipAt,
    DateTime? completedAt,
    KeeperStage? keeperStage,
  }) async {
    final Map<String, dynamic> data = {
      'status': status.name,
    };

    if (startedAt != null) {
      data['started_at'] =
          startedAt.toUtc().toIso8601String();
    }

    if (readyToShipAt != null) {
      data['ready_to_ship_at'] =
          readyToShipAt.toUtc().toIso8601String();
    }

    if (completedAt != null) {
      data['completed_at'] =
          completedAt.toUtc().toIso8601String();
    }

    if (keeperStage != null) {
      data['keeper_stage'] = keeperStage.name;
    }

    final response = await _client
        .from(tableName)
        .update(data)
        .eq('id', orderId)
        .eq('workspace_id', workspaceId)
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// UPDATE PEMBAYARAN
  /// ==========================================================

  Future<OrderData?> updatePayment({
    required String orderId,
    required String workspaceId,
    required PaymentStatus paymentStatus,
    DateTime? paidAt,
  }) async {
    final Map<String, dynamic> data = {
      'payment_status': paymentStatus.name,
      'paid_at': paidAt?.toUtc().toIso8601String(),
    };

    final response = await _client
        .from(tableName)
        .update(data)
        .eq('id', orderId)
        .eq('workspace_id', workspaceId)
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// UPDATE SHIPPING
  /// ==========================================================

  Future<OrderData?> updateShipping({
    required String orderId,
    required String workspaceId,
    String? shippingCourier,
    String? shippingReceiptFileName,
    DateTime? shippingDate,
  }) async {
    final Map<String, dynamic> data = {
      'shipping_courier': shippingCourier,
      'shipping_receipt_file_name':
      shippingReceiptFileName,
      'shipping_date':
      shippingDate?.toUtc().toIso8601String(),
    };

    final response = await _client
        .from(tableName)
        .update(data)
        .eq('id', orderId)
        .eq('workspace_id', workspaceId)
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// UPDATE PACKING
  /// ==========================================================

  Future<OrderData?> updatePacking({
    required String orderId,
    required String workspaceId,
    required PackingStatus packingStatus,
    DateTime? packedAt,
    DateTime? shippedAt,
    DateTime? receiptPrintedAt,
  }) async {
    final Map<String, dynamic> data = {
      'packing_status': packingStatus.name,
      'packed_at':
      packedAt?.toUtc().toIso8601String(),
      'shipped_at':
      shippedAt?.toUtc().toIso8601String(),
      'receipt_printed_at':
      receiptPrintedAt?.toUtc().toIso8601String(),
    };

    final response = await _client
        .from(tableName)
        .update(data)
        .eq('id', orderId)
        .eq('workspace_id', workspaceId)
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return OrderDataMapper.fromSupabaseMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// ==========================================================
  /// DELETE ORDER
  /// ==========================================================

  Future<void> deleteOrder({
    required String orderId,
    required String workspaceId,
  }) async {
    await _client
        .from(tableName)
        .delete()
        .eq('id', orderId)
        .eq('workspace_id', workspaceId);
  }

  /// ==========================================================
  /// REALTIME SEMUA ORDER
  /// ==========================================================

  Stream<List<OrderData>> watchOrders() {
    return _client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
          .map(
            (row) => OrderDataMapper.fromSupabaseMap(
          Map<String, dynamic>.from(row),
        ),
      )
          .toList(),
    );
  }

  /// ==========================================================
  /// REALTIME BERDASARKAN WORKSPACE
  /// ==========================================================

  Stream<List<OrderData>> watchOrdersByWorkspace(
      String workspaceId,
      ) {
    return _client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
          .map(
            (row) => OrderDataMapper.fromSupabaseMap(
          Map<String, dynamic>.from(row),
        ),
      )
          .toList(),
    );
  }
}

/// ============================================================
/// ORDERDATA → SUPABASE MAP
/// ============================================================

extension OrderDataSupabaseExtension on OrderData {
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'workspace_name': workspaceName,
      'admin_email': adminEmail,

      'product_name': productName,
      'ukuran': ukuran,
      'frame': frame,
      'price': price,
      'deadline_days': deadlineDays,
      'catatan': catatan,

      'product_image_file_name':
      productImageFileName,
      'product_image_url':
      productImageUrl,

      'status': status.name,

      'created_at':
      createdAt.toUtc().toIso8601String(),

      'started_at':
      startedAt?.toUtc().toIso8601String(),

      'ready_to_ship_at':
      readyToShipAt?.toUtc().toIso8601String(),

      'completed_at':
      completedAt?.toUtc().toIso8601String(),

      'payment_status':
      paymentStatus.name,

      'paid_at':
      paidAt?.toUtc().toIso8601String(),

      'shipping_courier':
      shippingCourier,

      'shipping_receipt_file_name':
      shippingReceiptFileName,
      'shipping_receipt_url':
      shippingReceiptUrl,

      'shipping_date':
      shippingDate?.toUtc().toIso8601String(),

      'keeper_stage':
      keeperStage.name,

      'requires_receipt_before_work':
      requiresReceiptBeforeWork,

      'packing_status':
      packingStatus.name,

      'packed_at':
      packedAt?.toUtc().toIso8601String(),

      'shipped_at':
      shippedAt?.toUtc().toIso8601String(),

      'receipt_printed_at':
      receiptPrintedAt?.toUtc().toIso8601String(),
    };
  }
}

/// ============================================================
/// SUPABASE MAP → ORDERDATA
/// ============================================================

class OrderDataMapper {
  const OrderDataMapper._();

  static OrderData fromSupabaseMap(
      Map<String, dynamic> map,
      ) {
    return OrderData(
      id: _string(map['id']),
      workspaceId: _string(map['workspace_id']),
      workspaceName: _string(map['workspace_name']),
      adminEmail: _string(map['admin_email']),

      productName: _string(map['product_name']),
      ukuran: _string(map['ukuran']),
      frame: _string(map['frame']),
      price: _int(map['price']),
      deadlineDays: _int(
        map['deadline_days'],
        fallback: 5,
      ),
      catatan: _string(map['catatan']),

      productImageUrl:
      _nullableString(
        map['product_image_url'],
      ),

      productImageFileName:
      _nullableString(
        map['product_image_file_name'],
      ),

      status: _orderStatus(
        map['status'],
      ),

      createdAt: _dateTime(
        map['created_at'],
      ),

      startedAt: _nullableDateTime(
        map['started_at'],
      ),

      readyToShipAt: _nullableDateTime(
        map['ready_to_ship_at'],
      ),

      completedAt: _nullableDateTime(
        map['completed_at'],
      ),

      paymentStatus: _paymentStatus(
        map['payment_status'],
      ),

      paidAt: _nullableDateTime(
        map['paid_at'],
      ),

      shippingCourier:
      _nullableString(
        map['shipping_courier'],
      ),

      shippingReceiptFileName:
      _nullableString(
        map['shipping_receipt_file_name'],
      ),

      shippingReceiptUrl:
      _nullableString(
        map['shipping_receipt_url'],
      ),

      shippingDate:
      _nullableDateTime(
        map['shipping_date'],
      ),

      keeperStage: _keeperStage(
        map['keeper_stage'],
      ),

      requiresReceiptBeforeWork:
      _bool(
        map['requires_receipt_before_work'],
        fallback: false,
      ),

      packingStatus: _packingStatus(
        map['packing_status'],
      ),

      packedAt:
      _nullableDateTime(
        map['packed_at'],
      ),

      shippedAt:
      _nullableDateTime(
        map['shipped_at'],
      ),

      receiptPrintedAt:
      _nullableDateTime(
        map['receipt_printed_at'],
      ),
    );
  }

  /// ==========================================================
  /// STRING
  /// ==========================================================

  static String _string(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _nullableString(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  /// ==========================================================
  /// INTEGER
  /// ==========================================================

  static int _int(
      dynamic value, {
        int fallback = 0,
      }) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        fallback;
  }

  /// ==========================================================
  /// BOOLEAN
  /// ==========================================================

  static bool _bool(
      dynamic value, {
        bool fallback = false,
      }) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return fallback;
  }

  /// ==========================================================
  /// DATETIME
  /// ==========================================================

  static DateTime _dateTime(
      dynamic value,
      ) {
    if (value is DateTime) {
      return value.toLocal();
    }

    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw FormatException(
        'created_at tidak valid: $value',
      );
    }

    return parsed.toLocal();
  }

  static DateTime? _nullableDateTime(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    final parsed = DateTime.tryParse(
      value.toString(),
    );

    return parsed?.toLocal();
  }

  /// ==========================================================
  /// ORDER STATUS
  /// ==========================================================

  static OrderStatus _orderStatus(
      dynamic value,
      ) {
    final name = value?.toString();

    return OrderStatus.values.firstWhere(
          (item) => item.name == name,
      orElse: () => OrderStatus.belumSelesai,
    );
  }

  /// ==========================================================
  /// PAYMENT STATUS
  /// ==========================================================

  static PaymentStatus _paymentStatus(
      dynamic value,
      ) {
    final name = value?.toString();

    return PaymentStatus.values.firstWhere(
          (item) => item.name == name,
      orElse: () => PaymentStatus.belumDibayar,
    );
  }

  /// ==========================================================
  /// KEEPER STAGE
  /// ==========================================================

  static KeeperStage _keeperStage(
      dynamic value,
      ) {
    final name = value?.toString();

    return KeeperStage.values.firstWhere(
          (item) => item.name == name,
      orElse: () => KeeperStage.orderanMasuk,
    );
  }

  /// ==========================================================
  /// PACKING STATUS
  /// ==========================================================

  static PackingStatus _packingStatus(
      dynamic value,
      ) {
    final name = value?.toString();

    return PackingStatus.values.firstWhere(
          (item) => item.name == name,
      orElse: () => PackingStatus.belumDipacking,
    );
  }
}

