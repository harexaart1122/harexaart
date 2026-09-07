// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../data/order_store.dart';

class _ImageCompressionResult {
  const _ImageCompressionResult({
    required this.bytes,
    required this.mimeType,
    required this.compressed,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool compressed;
}

class InputOrderPage extends StatefulWidget {
  final String adminEmail;
  final String workspaceId;
  final String workspaceName;

  const InputOrderPage({
    super.key,
    required this.adminEmail,
    required this.workspaceId,
    required this.workspaceName,
  });

  @override
  State<InputOrderPage> createState() => _InputOrderPageState();
}

class _InputOrderPageState extends State<InputOrderPage> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _customUkuranController =
  TextEditingController();
  final TextEditingController _customFrameController =
  TextEditingController();
  final TextEditingController _customHargaController =
  TextEditingController();

  // ============================================================
  // PILIHAN
  // ============================================================

  String? _selectedUkuran;
  String? _selectedFrame;
  int? _selectedDeadline;

  String? _gambarFileName;
  String? _resiFileName;
  String? _gambarMimeType;

  Uint8List? _gambarBytes;
  Uint8List? _resiBytes;
  String? _resiMimeType;

  // ============================================================
  // DATABASE UKURAN
  // SESUAI TABEL USER
  // ============================================================

  final List<String> _ukuranOptions = [
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

  // ============================================================
  // DATABASE FRAME
  // ============================================================

  final List<String> _frameOptions = [
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

  // ============================================================
  // DEADLINE 1 - 14 HARI
  // ============================================================

  final List<int> _deadlineOptions = List<int>.generate(
    14,
        (index) => index + 1,
  );

  // ============================================================
  // DATABASE HARGA
  //
  // ANGKA DIAMBIL PERSIS DARI TABEL USER
  //
  // Format:
  // Ukuran -> Frame -> Harga
  // ============================================================

  final Map<String, Map<String, int>> _priceDatabase = {
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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _catatanController.dispose();
    _customUkuranController.dispose();
    _customFrameController.dispose();
    _customHargaController.dispose();
    super.dispose();
  }

  // ============================================================
  // CEK CUSTOM
  // ============================================================

  bool get _isCustom {
    return _selectedUkuran == 'CUSTOM' || _selectedFrame == 'CUSTOM';
  }

  // ============================================================
  // HARGA STANDARD
  // ============================================================

  int? get _standardPrice {
    if (_selectedUkuran == null || _selectedFrame == null) {
      return null;
    }

    if (_isCustom) {
      return null;
    }

    return _priceDatabase[_selectedUkuran]?[_selectedFrame];
  }

  // ============================================================
  // HARGA CUSTOM
  // ============================================================

  int? get _customPrice {
    String raw = _customHargaController.text;

    raw = raw
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');

    if (raw.isEmpty) {
      return null;
    }

    return int.tryParse(raw);
  }

  // ============================================================
  // TOTAL HARGA
  // ============================================================

  int? get _totalPrice {
    if (_isCustom) {
      return _customPrice;
    }

    return _standardPrice;
  }

  // ============================================================
  // FORMAT RUPIAH
  // ============================================================

  String _formatRupiah(int? value) {
    if (value == null) {
      return '—';
    }

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

  // ============================================================
  // KOMPRES GAMBAR OTOMATIS - WEB
  // ============================================================

  static const int _maxImageDimension = 2560;
  static const double _imageQuality = 0.92;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _replaceImageExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0
        ? fileName.substring(0, dotIndex)
        : fileName;
    return '$baseName.webp';
  }

  Future<_ImageCompressionResult> _compressImageForUpload(
      Uint8List originalBytes,
      String originalMimeType,
      ) async {
    // GIF animasi sengaja tidak diubah ke canvas agar animasinya tidak
    // hilang. File asli tetap dipakai sehingga review tetap aman.
    if (originalMimeType.toLowerCase() == 'image/gif') {
      return _ImageCompressionResult(
        bytes: originalBytes,
        mimeType: originalMimeType,
        compressed: false,
      );
    }

    final originalDataUrl =
        'data:$originalMimeType;base64,${base64Encode(originalBytes)}';
    final image = html.ImageElement();
    final loaded = Completer<void>();

    image.onLoad.first.then((_) {
      if (!loaded.isCompleted) loaded.complete();
    });
    image.onError.first.then((_) {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('Browser tidak dapat membaca format gambar ini.'));
      }
    });

    image.src = originalDataUrl;

    try {
      await loaded.future;

      final sourceWidth = image.naturalWidth;
      final sourceHeight = image.naturalHeight;
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        return _ImageCompressionResult(
          bytes: originalBytes,
          mimeType: originalMimeType,
          compressed: false,
        );
      }

      final scale = (sourceWidth > _maxImageDimension ||
          sourceHeight > _maxImageDimension)
          ? _maxImageDimension /
          (sourceWidth > sourceHeight ? sourceWidth : sourceHeight)
          : 1.0;

      final targetWidth = (sourceWidth * scale).round();
      final targetHeight = (sourceHeight * scale).round();

      // Kalau dimensinya sudah kecil, tetap lewat encoder kualitas tinggi
      // hanya bila hasilnya benar-benar lebih kecil. Kalau tidak, file asli
      // dipertahankan agar tidak ada kerusakan kualitas yang tidak perlu.
      final canvas = html.CanvasElement(
        width: targetWidth,
        height: targetHeight,
      );
      final context = canvas.context2D;
      context.drawImageScaled(
        image,
        0,
        0,
        targetWidth,
        targetHeight,
      );

      String webpDataUrl;
      try {
        webpDataUrl = canvas.toDataUrl('image/webp', _imageQuality);
      } catch (_) {
        return _ImageCompressionResult(
          bytes: originalBytes,
          mimeType: originalMimeType,
          compressed: false,
        );
      }

      // Jangan pernah mengaku WebP kalau browser ternyata mengembalikan
      // format lain. Ini menjaga MIME type dan isi file tetap sinkron.
      if (!webpDataUrl.startsWith('data:image/webp;base64,')) {
        return _ImageCompressionResult(
          bytes: originalBytes,
          mimeType: originalMimeType,
          compressed: false,
        );
      }

      final commaIndex = webpDataUrl.indexOf(',');
      if (commaIndex == -1 || commaIndex == webpDataUrl.length - 1) {
        return _ImageCompressionResult(
          bytes: originalBytes,
          mimeType: originalMimeType,
          compressed: false,
        );
      }

      final compressedBytes = Uint8List.fromList(
        base64Decode(webpDataUrl.substring(commaIndex + 1)),
      );

      // Kalau hasil tidak lebih kecil, jangan pakai hasil kompresi.
      if (compressedBytes.isEmpty || compressedBytes.length >= originalBytes.length) {
        return _ImageCompressionResult(
          bytes: originalBytes,
          mimeType: originalMimeType,
          compressed: false,
        );
      }

      return _ImageCompressionResult(
        bytes: compressedBytes,
        mimeType: 'image/webp',
        compressed: true,
      );
    } catch (_) {
      // Format yang tidak bisa didecode browser tetap dipertahankan sebagai
      // file asli. Dengan begitu aplikasi tidak membuat file rusak.
      return _ImageCompressionResult(
        bytes: originalBytes,
        mimeType: originalMimeType,
        compressed: false,
      );
    }
  }

  // ============================================================
  // UPLOAD FILE - WEB
  // ============================================================

  Future<void> _pickFile({required bool isImage}) async {
    final input = html.FileUploadInputElement()
      ..accept = isImage
          ? 'image/*'
          : 'application/pdf,image/png,image/jpeg,image/jpg,image/webp'
      ..multiple = false;

    html.document.body?.append(input);

    try {
      input.click();
      await input.onChange.first;

      final files = input.files;
      if (files == null || files.isEmpty) {
        return;
      }

      final file = files.first;
      final reader = html.FileReader();

      // Gunakan Data URL, bukan readAsArrayBuffer.
      // Pada beberapa kombinasi Flutter Web/Dart/browser, result dari
      // readAsArrayBuffer tidak selalu terpapar sebagai ByteBuffer.
      // Data URL selalu kembali sebagai String sehingga lebih stabil.
      reader.readAsDataUrl(file);
      await reader.onLoadEnd.first;

      final result = reader.result;
      if (result is! String || result.isEmpty) {
        if (mounted) {
          _showError('File tidak dapat dibaca browser. Silakan coba file lain.');
        }
        return;
      }

      final commaIndex = result.indexOf(',');
      if (commaIndex == -1 || commaIndex == result.length - 1) {
        if (mounted) {
          _showError('Format file tidak valid atau file kosong.');
        }
        return;
      }

      final base64Data = result.substring(commaIndex + 1);
      final bytes = Uint8List.fromList(base64Decode(base64Data));
      if (bytes.isEmpty) {
        if (mounted) {
          _showError('File kosong dan tidak dapat digunakan.');
        }
        return;
      }

      if (!mounted) return;

      final mimeType = file.type.trim().isNotEmpty
          ? file.type.trim().toLowerCase()
          : (isImage ? 'image/jpeg' : 'application/pdf');

      if (isImage) {
        final compression = await _compressImageForUpload(
          bytes,
          mimeType,
        );

        if (!mounted) return;

        final finalFileName = compression.compressed
            ? _replaceImageExtension(file.name)
            : file.name;

        setState(() {
          _gambarBytes = compression.bytes;
          _gambarFileName = finalFileName;
          _gambarMimeType = compression.mimeType;
        });

        if (compression.compressed) {
          _showSuccess(
            'Gambar siap: ${_formatFileSize(bytes.length)} → ${_formatFileSize(compression.bytes.length)}',
          );
        } else {
          _showSuccess('Gambar siap digunakan: $finalFileName');
        }
      } else {
        setState(() {
          _resiBytes = bytes;
          _resiFileName = file.name;
          _resiMimeType = mimeType;
        });

        _showSuccess('Resi asli berhasil dibaca: ${file.name}');
      }
    } catch (error) {
      if (mounted) {
        _showError('Gagal membaca file: $error');
      }
    } finally {
      input.remove();
    }
  }

  Future<void> _selectGambar() async {
    await _pickFile(isImage: true);
  }

  Future<void> _selectResi() async {
    await _pickFile(isImage: false);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF21442F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _previewGambar() {
    final bytes = _gambarBytes;
    if (bytes == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF15171A),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_outlined, color: Color(0xFFD6B56A)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _gambarFileName ?? 'Gambar Order',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Image.memory(bytes, fit: BoxFit.contain),
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

  void _previewResi() {
    final bytes = _resiBytes;
    if (bytes == null) return;

    final mime = _resiMimeType ?? 'application/octet-stream';
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.window.open(url, '_blank');

    Future<void>.delayed(const Duration(minutes: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  void _testPrintFile({required bool isImage}) {
    final bytes = isImage ? _gambarBytes : _resiBytes;
    if (bytes == null) return;

    final mime = isImage
        ? (_gambarMimeType ?? 'image/jpeg')
        : (_resiMimeType ?? 'application/pdf');
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.window.open(url, '_blank');
    _showSuccess(
      isImage
          ? 'Gambar dibuka untuk tes print. Gunakan Ctrl+P / Print di browser.'
          : 'Resi dibuka untuk tes print. Gunakan tombol Print di viewer PDF.',
    );

    Future<void>.delayed(const Duration(minutes: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  // ============================================================
  // KIRIM KE PRODUKSI
  // ============================================================

  void _sendToProduction() {
    if (_gambarBytes == null || _gambarFileName == null) {
      _showError('Gambar order belum dipilih.');
      return;
    }

    if (_resiBytes == null || _resiFileName == null) {
      _showError('Resi belum dipilih.');
      return;
    }

    if (_selectedUkuran == null) {
      _showError('Silakan pilih ukuran.');
      return;
    }

    if (_selectedFrame == null) {
      _showError('Silakan pilih frame.');
      return;
    }

    if (_selectedDeadline == null) {
      _showError('Silakan pilih deadline.');
      return;
    }

    if (_isCustom) {
      if (_customUkuranController.text.trim().isEmpty) {
        _showError('Ukuran custom belum diisi.');
        return;
      }

      if (_customFrameController.text.trim().isEmpty) {
        _showError('Frame custom belum diisi.');
        return;
      }

      if (_customPrice == null) {
        _showError('Harga custom belum diisi.');
        return;
      }
    }

    _showConfirmation();
  }

  void _resetForm() {
    setState(() {
      _selectedUkuran = null;
      _selectedFrame = null;
      _selectedDeadline = null;
      _gambarFileName = null;
      _resiFileName = null;
      _gambarBytes = null;
      _resiBytes = null;
      _gambarMimeType = null;
      _resiMimeType = null;
      _catatanController.clear();
      _customUkuranController.clear();
      _customFrameController.clear();
      _customHargaController.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3A2520),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // KONFIRMASI
  // ============================================================

  void _showConfirmation() {
    final ukuran = _isCustom
        ? _customUkuranController.text
        : _selectedUkuran!;

    final frame = _isCustom
        ? _customFrameController.text
        : _selectedFrame!;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF191B1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: Color(0xFF34373D),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6B56A).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Color(0xFFD6B56A),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Konfirmasi Order',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  _confirmationRow(
                    'Workspace',
                    widget.workspaceName,
                  ),

                  _confirmationRow(
                    'Ukuran',
                    ukuran,
                  ),

                  _confirmationRow(
                    'Frame',
                    frame,
                  ),

                  _confirmationRow(
                    'Deadline',
                    '${_selectedDeadline!} hari',
                  ),

                  _confirmationRow(
                    'Gambar',
                    _gambarFileName ?? '-',
                  ),

                  _confirmationRow(
                    'Resi',
                    _resiFileName ?? '-',
                  ),

                  const Divider(
                    color: Color(0xFF30333A),
                    height: 28,
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL HARGA',
                        style: TextStyle(
                          color: Color(0xFF8D929B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        _formatRupiah(_totalPrice),
                        style: const TextStyle(
                          color: Color(0xFFD6B56A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFF3A3D43),
                            ),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('BATAL'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final price = _totalPrice;

                            if (price == null || price <= 0) {
                              Navigator.pop(dialogContext);
                              _showError(
                                'Harga order tidak valid. Silakan cek kembali ukuran, frame, atau harga custom.',
                              );
                              return;
                            }

                            final now = DateTime.now();
                            final prefix = widget.workspaceId == 'harexaart'
                                ? 'HRX'
                                : widget.workspaceId == 'lavanya_art'
                                ? 'LVA'
                                : 'ORD';

                            final orderId =
                                '$prefix-${now.millisecondsSinceEpoch}';

                            try {
                              await OrderStore.instance.addOrder(
                                OrderData(
                                  id: orderId,
                                  workspaceId: widget.workspaceId,
                                  workspaceName: widget.workspaceName,
                                  adminEmail: widget.adminEmail,
                                  productName: 'Lukisan',
                                  ukuran: ukuran,
                                  frame: frame,
                                  price: price,
                                  deadlineDays: _selectedDeadline!,
                                  catatan: _catatanController.text.trim(),
                                  productImage: _gambarBytes,
                                  productImageFileName: _gambarFileName,
                                  status: OrderStatus.belumSelesai,
                                  createdAt: now,
                                  shippingReceiptImage: _resiBytes,
                                  shippingReceiptFileName: _resiFileName,
                                  shippingDate: now,
                                ),
                              );

                              if (!mounted) return;
                              Navigator.pop(dialogContext);

                              _showSuccess(
                                'Order $orderId berhasil dikirim ke produksi lengkap dengan gambar & resi asli.',
                              );

                              _resetForm();
                            } catch (error) {
                              if (!mounted) return;
                              _showError(
                                'Order gagal disimpan ke Supabase. Tidak ada order yang dianggap berhasil.\n$error',
                              );
                            }

                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD6B56A),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'KIRIM SEKARANG',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _confirmationRow(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF737881),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101114),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 42 : 20,
                vertical: 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1250,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),

                      const SizedBox(height: 25),

                      _buildWorkspaceBanner(),

                      const SizedBox(height: 30),

                      _buildSectionTitle(
                        'Input Order',
                        'Masukkan data order yang akan diproses oleh tim produksi.',
                      ),

                      const SizedBox(height: 16),

                      _buildUploadSection(isDesktop),

                      const SizedBox(height: 30),

                      _buildSectionTitle(
                        'Spesifikasi Order',
                        'Pilih ukuran dan frame. Harga akan menyesuaikan otomatis.',
                      ),

                      const SizedBox(height: 16),

                      _buildProductionDetails(isDesktop),

                      const SizedBox(height: 20),

                      _buildCustomSection(),

                      const SizedBox(height: 20),

                      _buildPriceCard(),

                      const SizedBox(height: 30),

                      _buildSectionTitle(
                        'Deadline Produksi',
                        'Pilih jumlah hari yang diberikan untuk menyelesaikan order.',
                      ),

                      const SizedBox(height: 16),

                      _buildDeadlineCard(),

                      const SizedBox(height: 30),

                      _buildSectionTitle(
                        'Catatan',
                        'Tambahkan instruksi khusus untuk tim produksi jika diperlukan.',
                      ),

                      const SizedBox(height: 16),

                      _buildNotesSection(),

                      const SizedBox(height: 30),

                      _buildSubmitButton(),

                      const SizedBox(height: 18),

                      _buildFooterInfo(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D21),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF303238),
            ),
          ),
          child: const Icon(
            Icons.add_box_rounded,
            color: Color(0xFFD6B56A),
            size: 26,
          ),
        ),

        const SizedBox(width: 16),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Input Order',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Buat order baru dan kirim ke produksi.',
                style: TextStyle(
                  color: Color(0xFF9297A0),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WORKSPACE
  // ============================================================

  Widget _buildWorkspaceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF17191D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF303238),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF64C98B),
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 12),

          const Text(
            'WORKSPACE AKTIF',
            style: TextStyle(
              color: Color(0xFF7F858F),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(width: 12),

          Text(
            widget.workspaceName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),

          const Spacer(),

          Text(
            widget.workspaceId,
            style: const TextStyle(
              color: Color(0xFF696E77),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF777C85),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // UPLOAD
  // ============================================================

  Widget _buildUploadSection(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildUploadCard(
              icon: Icons.image_outlined,
              title: 'Gambar Order',
              description: 'Upload gambar order',
              formats: 'JPG • JPEG • PNG',
              fileName: _gambarFileName,
              onTap: _selectGambar,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: _buildUploadCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Resi',
              description: 'Upload file resi',
              formats: 'PDF • JPG • JPEG • PNG',
              fileName: _resiFileName,
              onTap: _selectResi,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildUploadCard(
          icon: Icons.image_outlined,
          title: 'Gambar Order',
          description: 'Upload gambar order',
          formats: 'JPG • JPEG • PNG',
          fileName: _gambarFileName,
          onTap: _selectGambar,
        ),

        const SizedBox(height: 16),

        _buildUploadCard(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Resi',
          description: 'Upload file resi',
          formats: 'PDF • JPG • JPEG • PNG',
          fileName: _resiFileName,
          onTap: _selectResi,
        ),
      ],
    );
  }

  Widget _buildUploadCard({
    required IconData icon,
    required String title,
    required String description,
    required String formats,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    final hasFile = fileName != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 245,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF17191D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasFile
                ? const Color(0xFFD6B56A).withOpacity(0.55)
                : const Color(0xFF2D3036),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFD6B56A).withOpacity(0.09),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                hasFile ? Icons.check_rounded : icon,
                color: const Color(0xFFD6B56A),
                size: 28,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              hasFile ? 'File siap' : title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              hasFile
                  ? fileName
                  : description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8B9099),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              formats,
              style: const TextStyle(
                color: Color(0xFF5F646D),
                fontSize: 11,
              ),
            ),

            if (hasFile) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: title == 'Gambar Order'
                        ? _previewGambar
                        : _previewResi,
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('LIHAT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD6B56A),
                      side: const BorderSide(color: Color(0xFF5A4A28)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: title == 'Gambar Order'
                        ? () => _testPrintFile(isImage: true)
                        : () => _testPrintFile(isImage: false),
                    icon: const Icon(Icons.print_outlined, size: 15),
                    label: const Text('TES PRINT'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: const Color(0xFFD6B56A),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 13),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF22252A),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                hasFile ? 'Ganti File' : 'Pilih File',
                style: const TextStyle(
                  color: Color(0xFFD0D3D8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UKURAN + FRAME
  // ============================================================

  Widget _buildProductionDetails(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildDropdown(
              label: 'Ukuran',
              icon: Icons.straighten_rounded,
              value: _selectedUkuran,
              hint: 'Pilih ukuran',
              items: _ukuranOptions,
              onChanged: (value) {
                setState(() {
                  _selectedUkuran = value;

                  if (value != 'CUSTOM') {
                    _customUkuranController.clear();
                  }
                });
              },
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: _buildDropdown(
              label: 'Frame',
              icon: Icons.crop_square_rounded,
              value: _selectedFrame,
              hint: 'Pilih frame',
              items: _frameOptions,
              onChanged: (value) {
                setState(() {
                  _selectedFrame = value;

                  if (value != 'CUSTOM') {
                    _customFrameController.clear();
                  }
                });
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildDropdown(
          label: 'Ukuran',
          icon: Icons.straighten_rounded,
          value: _selectedUkuran,
          hint: 'Pilih ukuran',
          items: _ukuranOptions,
          onChanged: (value) {
            setState(() {
              _selectedUkuran = value;

              if (value != 'CUSTOM') {
                _customUkuranController.clear();
              }
            });
          },
        ),

        const SizedBox(height: 16),

        _buildDropdown(
          label: 'Frame',
          icon: Icons.crop_square_rounded,
          value: _selectedFrame,
          hint: 'Pilih frame',
          items: _frameOptions,
          onChanged: (value) {
            setState(() {
              _selectedFrame = value;

              if (value != 'CUSTOM') {
                _customFrameController.clear();
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        17,
        7,
        17,
        5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF17191D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF2D3036),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF1D2025),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF777C85),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF8A8F98),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFFD6B56A),
            size: 21,
          ),
          border: InputBorder.none,
        ),
        hint: Text(
          hint,
          style: const TextStyle(
            color: Color(0xFF5F646D),
            fontSize: 14,
          ),
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ============================================================
  // CUSTOM
  // ============================================================

  Widget _buildCustomSection() {
    if (!_isCustom) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD6B56A).withOpacity(0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6B56A).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFFD6B56A),
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUSTOM ORDER',
                    style: TextStyle(
                      color: Color(0xFFD6B56A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Isi ukuran, frame, dan harga secara manual.',
                    style: TextStyle(
                      color: Color(0xFF777C85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          _buildTextInput(
            controller: _customUkuranController,
            label: 'Ukuran Custom',
            hint: 'Contoh: 135×85 cm',
            icon: Icons.straighten_rounded,
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: 14),

          _buildTextInput(
            controller: _customFrameController,
            label: 'Frame Custom',
            hint: 'Contoh: Frame kayu custom',
            icon: Icons.crop_square_rounded,
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: 14),

          _buildTextInput(
            controller: _customHargaController,
            label: 'Harga Custom',
            hint: 'Contoh: 450000',
            icon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) {
        setState(() {});
      },
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: Color(0xFF8A8F98),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF5F646D),
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFD6B56A),
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFF17191D),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFF2D3036),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFD6B56A),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HARGA
  // ============================================================

  Widget _buildPriceCard() {
    final total = _totalPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF17191D),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFD6B56A).withOpacity(0.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD6B56A).withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFFD6B56A),
              size: 24,
            ),
          ),

          const SizedBox(width: 15),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL HARGA',
                  style: TextStyle(
                    color: Color(0xFF858A93),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Mengikuti pilihan ukuran & frame',
                  style: TextStyle(
                    color: Color(0xFF5F646D),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            _formatRupiah(total),
            style: TextStyle(
              color: total == null
                  ? const Color(0xFF626770)
                  : const Color(0xFFD6B56A),
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DEADLINE
  // ============================================================

  Widget _buildDeadlineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        17,
        7,
        17,
        5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF17191D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF2D3036),
        ),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedDeadline,
        dropdownColor: const Color(0xFF1D2025),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF777C85),
        ),
        decoration: const InputDecoration(
          labelText: 'Deadline Produksi',
          labelStyle: TextStyle(
            color: Color(0xFF8A8F98),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.schedule_rounded,
            color: Color(0xFFD6B56A),
            size: 21,
          ),
          border: InputBorder.none,
        ),
        hint: const Text(
          'Pilih deadline',
          style: TextStyle(
            color: Color(0xFF5F646D),
            fontSize: 14,
          ),
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: _deadlineOptions.map((days) {
          return DropdownMenuItem<int>(
            value: days,
            child: Text('$days hari'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedDeadline = value;
          });
        },
      ),
    );
  }

  // ============================================================
  // CATATAN
  // ============================================================

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF2D3036),
        ),
      ),
      child: TextField(
        controller: _catatanController,
        minLines: 4,
        maxLines: 7,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText:
          'Tulis catatan atau instruksi khusus untuk produksi...',
          hintStyle: TextStyle(
            color: Color(0xFF5F646D),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(
              bottom: 72,
            ),
            child: Icon(
              Icons.notes_rounded,
              color: Color(0xFFD6B56A),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUTTON
  // ============================================================

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _sendToProduction,
        icon: const Icon(
          Icons.rocket_launch_rounded,
          size: 21,
        ),
        label: const Text(
          'KIRIM KE PRODUKSI',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD6B56A),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooterInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFF5D626B),
          size: 14,
        ),

        const SizedBox(width: 7),

        Flexible(
          child: Text(
            'Order akan tercatat pada workspace ${widget.workspaceName}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5D626B),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
