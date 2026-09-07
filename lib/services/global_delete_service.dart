import 'package:flutter/foundation.dart';

import '../data/order_store.dart';

/// Service khusus untuk fitur Hapus Global.
///
/// Tugas service ini:
/// - memastikan order berasal dari workspace yang sedang aktif
/// - menjadi pintu masuk fitur delete global
/// - meneruskan proses delete ke OrderStore
///
/// Prinsip penting:
/// HarexaArt tidak boleh menghapus order Lavanya Art.
/// Lavanya Art tidak boleh menghapus order HarexaArt.
class GlobalDeleteService {
  GlobalDeleteService._();

  static final GlobalDeleteService instance = GlobalDeleteService._();

  /// Menghapus beberapa order sekaligus.
  ///
  /// [workspaceId] adalah workspace admin yang sedang aktif.
  /// [orderIds] adalah ID order yang dipilih oleh admin.
  ///
  /// Hasil:
  /// - mengembalikan ID order yang berhasil dihapus
  /// - jika gagal, error diteruskan ke pemanggil
  Future<List<String>> deleteOrders({
    required String workspaceId,
    required List<String> orderIds,
  }) async {
    if (workspaceId.trim().isEmpty) {
      throw ArgumentError('Workspace ID tidak boleh kosong.');
    }

    if (orderIds.isEmpty) {
      return <String>[];
    }

    final cleanOrderIds = orderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanOrderIds.isEmpty) {
      return <String>[];
    }

    debugPrint(
      'GLOBAL DELETE: mulai menghapus '
          '${cleanOrderIds.length} order '
          'dari workspace $workspaceId',
    );

    final deletedIds = await OrderStore.instance.adminDeleteOrdersGlobal(
      orderIds: cleanOrderIds,
      workspaceId: workspaceId,
    );

    debugPrint(
      'GLOBAL DELETE: berhasil menghapus '
          '${deletedIds.length} order '
          'dari workspace $workspaceId',
    );

    return deletedIds;
  }

  /// Menghapus semua order dalam satu kelompok/progres.
  ///
  /// Fungsi ini nanti akan dipakai oleh tombol kecil
  /// ikon tong sampah pada:
  ///
  /// ORDERAN BARU
  /// SEDANG DIPROSES
  /// SELESAI
  ///
  /// Untuk sekarang kita siapkan fondasinya dulu.
  Future<List<String>> deleteOrdersByIds({
    required String workspaceId,
    required Iterable<String> orderIds,
  }) {
    return deleteOrders(
      workspaceId: workspaceId,
      orderIds: orderIds.toList(),
    );
  }
}