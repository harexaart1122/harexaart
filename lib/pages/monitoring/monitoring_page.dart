import 'dart:async';
import 'dart:typed_data';
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/order_store.dart';
import '../../services/attendance_service.dart';

/// ===============================================================
/// HAREXAART / LAVANYA ART
/// MONITORING V3.2 - DUAL LIVE ORDER FLOW / CONVEYOR
///
/// Prinsip:
/// - Satu layar, tanpa sidebar.
/// - Dua lane permanen berdampingan: HarexaArt kiri, Lavanya Art kanan.
/// - Read-only terhadap OrderStore.
/// - Tidak menampilkan harga/nominal.
/// - Semua order yang tampil bisa REVIEW GAMBAR.
/// - Setiap order WAJIB punya tombol REVIEW GAMBAR + LIHAT RESI berdampingan.
/// - LIHAT RESI tetap aktif; jika belum ada resi, dialog menjelaskan resi belum input.
/// - Event produksi memunculkan highlight + voice announcement.
/// - Deadline dihitung dari createdAt + deadlineDays.
/// - Statistik memakai completedAt.
/// - Tidak membuat database/order list baru.
/// ===============================================================

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  Timer? _clockTimer;
  Timer? _refreshTimer;
  DateTime _now = DateTime.now();

  List<OrderData> _orders = <OrderData>[];
  final Set<String> _knownOrderIds = <String>{};
  final Map<String, KeeperStage> _knownStages = <String, KeeperStage>{};
  final Map<String, String> _knownShippingEvents = <String, String>{};
  final Map<String, DateTime?> _knownCompletedAt = <String, DateTime?>{};

  final List<_VoiceEvent> _voiceQueue = <_VoiceEvent>[];
  final Set<String> _deadlineAnnouncedKeys = <String>{};
  final Set<String> _selectedPackingOrderIds = <String>{};
  bool _speaking = false;
  bool _voiceEnabled = true;
  double _scrollSpeed = 1.35;
  _ArchiveRange _archiveRange = _ArchiveRange.today;
  DateTime? _archiveCustomStart;
  DateTime? _archiveCustomEnd;

  String? _highlightOrderId;
  _HighlightType _highlightType = _HighlightType.none;

  String _lastAnnouncement = 'Belum ada pengumuman.';
  DateTime? _lastAnnouncementAt;

  // ===============================================================
  // ATTENDANCE — MODUL TERPISAH DARI ORDER
  // Foto hanya disimpan di memory browser dan TIDAK pernah dikirim
  // ke Supabase / Storage.
  // ===============================================================
  final AttendanceService _attendanceService = AttendanceService.instance;
  List<AttendanceRecord> _attendanceRecords = <AttendanceRecord>[];
  final Set<String> _knownAttendanceIds = <String>{};
  final Map<String, Uint8List> _attendancePhotos = <String, Uint8List>{};
  String _attendanceDateKey = '';

  @override
  void initState() {
    super.initState();

    OrderStore.instance.addListener(_syncFromStore);
    _syncFromStore();

    _attendanceDateKey = _attendanceService.todayWib;
    unawaited(_loadTodayAttendance());
    _attendanceService.startRealtime(
      onChanged: _handleAttendanceRealtime,
    );

    // Monitoring adalah layar GLOBAL.
    // Selalu hydrate ulang dari Supabase tanpa filter workspace agar
    // HarexaArt dan Lavanya Art sama-sama tersedia di satu monitor.
    unawaited(_loadMonitoringOrders());

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
          _checkAttendanceDayReset();
        }
      },
    );

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _syncFromStore(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    OrderStore.instance.removeListener(_syncFromStore);
    unawaited(_attendanceService.stopRealtime());
    _attendancePhotos.clear();
    _stopBrowserSpeech();
    super.dispose();
  }

  Future<void> _loadMonitoringOrders() async {
    try {
      await OrderStore.instance.loadFromSupabase();
      _syncFromStore();
    } catch (error, stackTrace) {
      // Jangan membuat Monitoring blank hanya karena request refresh gagal.
      // Data yang sudah ada di OrderStore tetap dipakai.
      debugPrint('MONITORING SUPABASE LOAD GAGAL: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _loadTodayAttendance() async {
    try {
      final records = await _attendanceService.loadToday();
      if (!mounted) return;

      final today = _attendanceService.todayWib;
      _attendanceDateKey = today;
      _attendanceRecords = records
          .where((record) => record.attendanceDate == today)
          .toList();
      _knownAttendanceIds
        ..clear()
        ..addAll(_attendanceRecords.map((record) => record.id));

      setState(() {});
    } catch (error, stackTrace) {
      debugPrint('ATTENDANCE LOAD GAGAL: $error');
      debugPrint('$stackTrace');
    }
  }

  void _checkAttendanceDayReset() {
    final today = _attendanceService.todayWib;
    if (_attendanceDateKey == today) return;

    _attendanceDateKey = today;
    _attendanceRecords = <AttendanceRecord>[];
    _knownAttendanceIds.clear();
    _attendancePhotos.clear();

    if (mounted) {
      setState(() {});
    }

    unawaited(_loadTodayAttendance());
  }

  void _handleAttendanceRealtime(AttendanceRecord record) {
    _checkAttendanceDayReset();

    final today = _attendanceService.todayWib;
    if (record.attendanceDate != today) return;

    final wasKnown = _knownAttendanceIds.contains(record.id);
    _knownAttendanceIds.add(record.id);

    final index = _attendanceRecords.indexWhere(
          (item) => item.id == record.id,
    );

    if (index >= 0) {
      _attendanceRecords[index] = record;
    } else {
      _attendanceRecords = <AttendanceRecord>[
        ..._attendanceRecords,
        record,
      ];
    }

    if (mounted) {
      setState(() {});
    }

    // Event dari perangkat lain / realtime baru.
    // Event yang sudah kita masukkan sendiri tidak diumumkan ulang.
    if (!wasKnown) {
      _notifyAttendance(record);
      _queueAttendanceVoice(record);
    }
  }

  void _upsertLocalAttendance(AttendanceRecord record) {
    _checkAttendanceDayReset();

    final index = _attendanceRecords.indexWhere(
          (item) => item.id == record.id,
    );

    _knownAttendanceIds.add(record.id);

    if (index >= 0) {
      _attendanceRecords[index] = record;
    } else {
      _attendanceRecords = <AttendanceRecord>[
        ..._attendanceRecords,
        record,
      ];
    }

    if (mounted) {
      setState(() {});
    }

    _notifyAttendance(record);
    _queueAttendanceVoice(record);
  }

  void _notifyAttendance(AttendanceRecord record) {
    if (!mounted) return;

    final message = record.isPresent
        ? '🟢 ${record.name} sudah datang • No. ${record.slot?.toString().padLeft(2, '0') ?? '-'}'
        : '🔴 ${record.name} tidak hadir • ${record.reason ?? '-'}';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: record.isPresent
              ? const Color(0xFF173D28)
              : const Color(0xFF461E22),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
  }

  void _queueAttendanceVoice(AttendanceRecord record) {
    final key = 'attendance-${record.id}';
    if (_voiceQueue.any((event) => event.key == key)) return;

    final text = record.isPresent
        ? '${record.name} sudah datang. Nomor urutan kedatangan ${record.slot}.'
        : '${record.name} tidak hadir karena ${record.reason ?? 'alasan belum tersedia'}.';

    _voiceQueue.add(
      _VoiceEvent(
        key: key,
        priority: 1,
        text: text,
        orderId: '',
        type: _HighlightType.attendance,
      ),
    );

    _processVoiceQueue();
  }

  List<AttendanceRecord> get _sortedAttendance {
    final list = List<AttendanceRecord>.from(_attendanceRecords);
    list.sort((a, b) {
      if (a.isPresent && b.isPresent) {
        return (a.slot ?? 99).compareTo(b.slot ?? 99);
      }
      if (a.isPresent) return -1;
      if (b.isPresent) return 1;
      return a.checkedInAt.compareTo(b.checkedInAt);
    });
    return list;
  }

  List<AttendanceRecord> get _presentAttendance =>
      _sortedAttendance.where((record) => record.isPresent).toList();

  List<AttendanceRecord> get _absentAttendance =>
      _sortedAttendance.where((record) => record.isAbsent).toList();

  bool _attendanceNameTaken(String name) {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return false;

    return _attendanceRecords.any(
          (record) => record.name.trim().toLowerCase() == clean,
    );
  }

  Future<void> _pickAttendancePhoto(
      void Function(Uint8List bytes) onPicked,
      ) async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..setAttribute('capture', 'environment');

    input.click();

    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;

    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final result = reader.result;
    if (result is ByteBuffer) {
      onPicked(Uint8List.view(result));
      return;
    }

    if (result is Uint8List) {
      onPicked(result);
    }
  }

  Future<bool> _submitPresentAttendance({
    required int slot,
    required String name,
    required Uint8List photoBytes,
  }) async {
    try {
      final record = await _attendanceService.markPresent(
        slot: slot,
        name: name,
      );

      // Foto hanya hidup di memory browser. Tidak pernah masuk record.
      _attendancePhotos[record.id] = photoBytes;
      _upsertLocalAttendance(record);

      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    } catch (error) {
      if (!mounted) return false;

      final message = error.toString().contains('23505')
          ? 'Nomor atau nama tersebut sudah dipakai hari ini.'
          : 'Absen gagal: $error';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4A2024),
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      return false;
    }
  }

  Future<bool> _submitAbsentAttendance({
    required String name,
    required String reason,
  }) async {
    try {
      final record = await _attendanceService.markAbsent(
        name: name,
        reason: reason,
      );

      _upsertLocalAttendance(record);

      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    } catch (error) {
      if (!mounted) return false;

      final message = error.toString().contains('23505')
          ? 'Nama tersebut sudah memiliki status absensi hari ini.'
          : 'Input tidak hadir gagal: $error';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4A2024),
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      return false;
    }
  }

  Future<void> _showAttendanceDialog({
    bool startAbsent = false,
  }) async {
    final nameController = TextEditingController();
    final reasonController = TextEditingController();

    bool absentMode = startAbsent;
    int? selectedSlot;
    Uint8List? photoBytes;
    bool submitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final cleanName = nameController.text.trim();
              final cleanReason = reasonController.text.trim();
              final nameTaken = _attendanceNameTaken(cleanName);

              final canSubmitPresent =
                  !absentMode &&
                      selectedSlot != null &&
                      cleanName.isNotEmpty &&
                      photoBytes != null &&
                      !nameTaken &&
                      !submitting;

              final canSubmitAbsent =
                  absentMode &&
                      cleanName.isNotEmpty &&
                      cleanReason.isNotEmpty &&
                      !nameTaken &&
                      !submitting;

              return Dialog(
                backgroundColor: const Color(0xFF101216),
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 650,
                    maxHeight: 760,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2B1E10),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: const Color(0xFF9B6324),
                                ),
                              ),
                              child: const Icon(
                                Icons.how_to_reg_rounded,
                                color: Color(0xFFF19A3E),
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ABSENSI HARI INI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Data reset otomatis setiap 00:00 WIB.',
                                    style: TextStyle(
                                      color: Color(0xFF747B85),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF858B94),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _attendanceModeButton(
                                label: 'ABSEN HADIR',
                                icon: Icons.login_rounded,
                                active: !absentMode,
                                color: const Color(0xFF58C781),
                                onTap: submitting
                                    ? null
                                    : () => setDialogState(
                                      () => absentMode = false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _attendanceModeButton(
                                label: 'TIDAK KERJA',
                                icon: Icons.event_busy_outlined,
                                active: absentMode,
                                color: const Color(0xFFE15A5A),
                                onTap: submitting
                                    ? null
                                    : () => setDialogState(
                                      () => absentMode = true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: absentMode
                                ? _buildAbsentAttendanceForm(
                              nameController: nameController,
                              reasonController: reasonController,
                              nameTaken: nameTaken,
                              submitting: submitting,
                              onChanged: () => setDialogState(() {}),
                            )
                                : _buildPresentAttendanceForm(
                              nameController: nameController,
                              selectedSlot: selectedSlot,
                              photoBytes: photoBytes,
                              nameTaken: nameTaken,
                              submitting: submitting,
                              onSlotChanged: (slot) => setDialogState(
                                    () => selectedSlot = slot,
                              ),
                              onPhotoChanged: (bytes) => setDialogState(
                                    () => photoBytes = bytes,
                              ),
                              onChanged: () => setDialogState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: absentMode
                                ? canSubmitAbsent
                                ? () async {
                              setDialogState(
                                    () => submitting = true,
                              );
                              final success =
                              await _submitAbsentAttendance(
                                name: cleanName,
                                reason: cleanReason,
                              );
                              if (!success) {
                                setDialogState(
                                      () => submitting = false,
                                );
                              }
                            }
                                : null
                                : canSubmitPresent
                                ? () async {
                              setDialogState(
                                    () => submitting = true,
                              );
                              final success =
                              await _submitPresentAttendance(
                                slot: selectedSlot!,
                                name: cleanName,
                                photoBytes: photoBytes!,
                              );
                              if (!success) {
                                setDialogState(
                                      () => submitting = false,
                                );
                              }
                            }
                                : null,
                            icon: Icon(
                              absentMode
                                  ? Icons.person_off_outlined
                                  : Icons.how_to_reg_rounded,
                              size: 17,
                            ),
                            label: Text(
                              submitting
                                  ? 'MENYIMPAN...'
                                  : absentMode
                                  ? 'SIMPAN TIDAK HADIR'
                                  : 'KONFIRMASI ABSEN',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: absentMode
                                  ? const Color(0xFF9B3338)
                                  : const Color(0xFFB96C22),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                              const Color(0xFF292D33),
                              disabledForegroundColor:
                              const Color(0xFF666D76),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
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
        },
      );
    } finally {
      nameController.dispose();
      reasonController.dispose();
    }
  }

  Widget _attendanceModeButton({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        foregroundColor: active ? color : const Color(0xFF777E87),
        backgroundColor:
        active ? color.withOpacity(.10) : const Color(0xFF15181D),
        side: BorderSide(
          color: active ? color.withOpacity(.55) : const Color(0xFF30353D),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );
  }

  Widget _buildPresentAttendanceForm({
    required TextEditingController nameController,
    required int? selectedSlot,
    required Uint8List? photoBytes,
    required bool nameTaken,
    required bool submitting,
    required ValueChanged<int> onSlotChanged,
    required ValueChanged<Uint8List> onPhotoChanged,
    required VoidCallback onChanged,
  }) {
    final usedSlots = _presentAttendance
        .map((record) => record.slot)
        .whereType<int>()
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'URUTAN KEDATANGAN • 01–10',
          style: TextStyle(
            color: Color(0xFFD9B55F),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: List.generate(10, (index) {
            final slot = index + 1;
            final used = usedSlots.contains(slot);
            final active = selectedSlot == slot;

            return ChoiceChip(
              label: Text(
                slot.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: used
                      ? const Color(0xFF5F6670)
                      : active
                      ? Colors.black
                      : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              selected: active,
              onSelected: used || submitting
                  ? null
                  : (_) => onSlotChanged(slot),
              selectedColor: const Color(0xFFD9B55F),
              backgroundColor: const Color(0xFF171A1F),
              disabledColor: const Color(0xFF111317),
              side: BorderSide(
                color: used
                    ? const Color(0xFF242830)
                    : active
                    ? const Color(0xFFD9B55F)
                    : const Color(0xFF30353D),
              ),
              showCheckmark: false,
            );
          }),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: nameController,
          enabled: !submitting,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: 'NAMA',
            hintText: 'Contoh: Nizar',
            labelStyle: const TextStyle(
              color: Color(0xFF7D838C),
              fontSize: 9,
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF555C65),
              fontSize: 11,
            ),
            errorText: nameTaken
                ? 'Nama sudah memiliki status absensi hari ini'
                : null,
            filled: true,
            fillColor: const Color(0xFF15181D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFF2D323A)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildAttendancePhotoPicker(
          photoBytes: photoBytes,
          submitting: submitting,
          onPick: () async {
            await _pickAttendancePhoto(onPhotoChanged);
          },
        ),
      ],
    );
  }

  Widget _buildAbsentAttendanceForm({
    required TextEditingController nameController,
    required TextEditingController reasonController,
    required bool nameTaken,
    required bool submitting,
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATUS TIDAK HADIR',
          style: TextStyle(
            color: Color(0xFFE15A5A),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          enabled: !submitting,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: 'NAMA',
            hintText: 'Contoh: Nizar',
            labelStyle: const TextStyle(
              color: Color(0xFF7D838C),
              fontSize: 9,
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF555C65),
              fontSize: 11,
            ),
            errorText: nameTaken
                ? 'Nama sudah memiliki status absensi hari ini'
                : null,
            filled: true,
            fillColor: const Color(0xFF15181D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFF2D323A)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reasonController,
          enabled: !submitting,
          maxLines: 4,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: 'ALASAN / KETERANGAN',
            hintText: 'Contoh: Ada keperluan keluarga',
            labelStyle: const TextStyle(
              color: Color(0xFF7D838C),
              fontSize: 9,
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF555C65),
              fontSize: 11,
            ),
            filled: true,
            fillColor: const Color(0xFF15181D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFF2D323A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendancePhotoPicker({
    required Uint8List? photoBytes,
    required bool submitting,
    required VoidCallback onPick,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: photoBytes == null
              ? const Color(0xFF4A3D24)
              : const Color(0xFF2E5A40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FOTO SUDAH DI LOKASI',
            style: TextStyle(
              color: Color(0xFFD9B55F),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Foto hanya untuk formalitas. Tidak disimpan di Supabase.',
            style: TextStyle(
              color: Color(0xFF686F79),
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 10),
          if (photoBytes != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photoBytes,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Foto siap dikirim bersama konfirmasi. File foto tetap lokal di perangkat ini.',
                    style: const TextStyle(
                      color: Color(0xFF7DCA9A),
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          if (photoBytes != null) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: submitting ? null : onPick,
            icon: const Icon(Icons.camera_alt_outlined, size: 15),
            label: Text(
              photoBytes == null ? 'AMBIL / UPLOAD FOTO' : 'GANTI FOTO',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBar() {
    final records = _sortedAttendance;
    final present = _presentAttendance;
    final absent = _absentAttendance;
    final first = present.isEmpty ? null : present.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 760;

        return Container(
          constraints: BoxConstraints(minHeight: mobile ? 76 : 66),
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 8 : 14,
            vertical: 7,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0B0D10),
            border: Border(
              bottom: BorderSide(color: Color(0xFF1E2229)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B1E10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF7B5227),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.how_to_reg_rounded,
                      color: Color(0xFFF19A3E),
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ABSEN',
                      style: TextStyle(
                        color: Color(0xFFF19A3E),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _attendanceCountPill(
                label: 'HADIR',
                value: '${present.length}',
                color: const Color(0xFF63C88A),
              ),
              const SizedBox(width: 6),
              _attendanceCountPill(
                label: 'TIDAK',
                value: '${absent.length}',
                color: const Color(0xFFE15A5A),
              ),
              if (first != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🥇 ${first.name.toUpperCase()} • DATANG PERTAMA / TELADAN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD9B55F),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () => _showAttendanceDialog(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                  label: Text(
                    mobile ? 'ABSEN' : 'ABSEN SEKARANG',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB96C22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _attendanceCountPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(.24),
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showAttendanceOverview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF101216),
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
              maxHeight: 760,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _dialogHeader(
                    title: 'ABSENSI HARI INI',
                    subtitle:
                    '${_attendanceDateKey.isEmpty ? _attendanceService.todayWib : _attendanceDateKey} • WIB',
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _attendanceCountPill(
                          label: 'HADIR',
                          value: '${_presentAttendance.length}',
                          color: const Color(0xFF63C88A),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _attendanceCountPill(
                          label: 'TIDAK HADIR',
                          value: '${_absentAttendance.length}',
                          color: const Color(0xFFE15A5A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _attendanceRecords.isEmpty
                        ? const Center(
                      child: Text(
                        'BELUM ADA ABSENSI HARI INI.',
                        style: TextStyle(
                          color: Color(0xFF68707A),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                        : ListView.separated(
                      itemCount: _sortedAttendance.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 7),
                      itemBuilder: (_, index) {
                        return _buildAttendanceRow(
                          _sortedAttendance[index],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _showAttendanceDialog();
                          },
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'ABSEN HADIR',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _showAttendanceDialog(startAbsent: true);
                          },
                          icon: const Icon(
                            Icons.event_busy_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'TIDAK KERJA',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
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

  Widget _buildAttendanceRow(AttendanceRecord record) {
    final photo = _attendancePhotos[record.id];

    if (record.isAbsent) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF171316),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF51282C),
          ),
        ),
        child: Row(
          children: [
            _attendanceAvatar(photo, record.isAbsent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔴 ${record.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TIDAK HADIR • Alasan: ${record.reason ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE58B8B),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(record.checkedInAt.toLocal()),
              style: const TextStyle(
                color: Color(0xFF777E87),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final slot = record.slot ?? 0;
    final isFirst = slot == 1;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFirst
            ? const Color(0xFF1B1810)
            : const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFirst
              ? const Color(0xFF8A6D2E)
              : const Color(0xFF2A3038),
        ),
      ),
      child: Row(
        children: [
          _attendanceRankBadge(slot, isFirst),
          const SizedBox(width: 10),
          _attendanceAvatar(photo, false),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isFirst
                      ? '🟢 AKTIF • DATANG PERTAMA / TELADAN'
                      : '🟢 AKTIF • DATANG KE-$slot',
                  style: TextStyle(
                    color: isFirst
                        ? const Color(0xFFD9B55F)
                        : const Color(0xFF72CA92),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(record.checkedInAt.toLocal()),
            style: const TextStyle(
              color: Color(0xFF777E87),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceRankBadge(int slot, bool first) {
    final medal = slot == 1
        ? '🥇'
        : slot == 2
        ? '🥈'
        : slot == 3
        ? '🥉'
        : slot.toString().padLeft(2, '0');

    return Container(
      width: 46,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: first ? const Color(0xFF302715) : const Color(0xFF20242A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: first ? const Color(0xFF80662B) : const Color(0xFF30353D),
        ),
      ),
      child: Text(
        medal,
        style: TextStyle(
          color: first ? const Color(0xFFD9B55F) : Colors.white,
          fontSize: first ? 18 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _attendanceAvatar(Uint8List? photo, bool absent) {
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E23),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: absent
              ? const Color(0xFF51282C)
              : const Color(0xFF2D4F3A),
        ),
      ),
      child: photo == null
          ? Icon(
        absent
            ? Icons.person_off_outlined
            : Icons.person_outline_rounded,
        color: absent
            ? const Color(0xFFE15A5A)
            : const Color(0xFF67C78C),
        size: 20,
      )
          : Image.memory(
        photo,
        fit: BoxFit.cover,
      ),
    );
  }

  void _syncFromStore() {
    final latest = List<OrderData>.from(OrderStore.instance.orders);

    final oldById = <String, OrderData>{
      for (final order in _orders) order.id: order,
    };

    for (final order in latest) {
      final old = oldById[order.id];

      if (old == null && !_knownOrderIds.contains(order.id)) {
        _knownOrderIds.add(order.id);
        _knownStages[order.id] = order.keeperStage;
        _knownShippingEvents[order.id] = _shippingEventSignature(order);
        _knownCompletedAt[order.id] = order.completedAt;

        // Jangan mengumumkan seluruh order lama saat Monitoring pertama
        // kali dibuka. Order baru yang masuk setelah monitor aktif akan
        // mendapatkan voice "ORDER BARU".
        if (_orders.isNotEmpty || latest.length == 1) {
          _queueNewOrderAnnouncement(order);
        }
      } else if (old != null) {
        final previousStage = _knownStages[order.id];

        if (previousStage != null &&
            previousStage != order.keeperStage) {
          _knownStages[order.id] = order.keeperStage;
          _queueStageAnnouncement(
            order,
            previousStage,
            order.keeperStage,
          );
        } else {
          _knownStages[order.id] = order.keeperStage;
        }

        final previousShipping =
            _knownShippingEvents[order.id] ?? '';
        final currentShipping = _shippingEventSignature(order);

        if (previousShipping != currentShipping &&
            currentShipping.isNotEmpty) {
          _knownShippingEvents[order.id] = currentShipping;

          // Jika resi berubah/baru diinput, voice tetap diumumkan walaupun
          // stage sudah lebih dulu berada di INPUT RESI.
          if (order.shippingReceiptImage != null ||
              (order.shippingReceiptUrl?.trim().isNotEmpty ?? false) ||
              order.shippingDate != null ||
              order.shippingCourier != null) {
            _queueReceiptAnnouncement(order);
          }
        }

        _knownCompletedAt[order.id] = order.completedAt;
      } else {
        _knownStages[order.id] = order.keeperStage;
        _knownShippingEvents[order.id] = _shippingEventSignature(order);
        _knownCompletedAt[order.id] = order.completedAt;
      }
    }

    // Bersihkan cache order yang sudah benar-benar tidak ada di store.
    final currentIds = latest.map((order) => order.id).toSet();
    _knownOrderIds.removeWhere((id) => !currentIds.contains(id));
    _knownStages.removeWhere((id, _) => !currentIds.contains(id));
    _knownShippingEvents.removeWhere((id, _) => !currentIds.contains(id));
    _knownCompletedAt.removeWhere((id, _) => !currentIds.contains(id));

    _orders = latest;

    if (mounted) {
      setState(() {});
    }

    _processVoiceQueue();
  }

  String _shippingEventSignature(OrderData order) {
    return [
      order.shippingCourier ?? '',
      order.shippingReceiptFileName ?? '',
      order.shippingDate?.millisecondsSinceEpoch.toString() ?? '',
      order.shippingReceiptImage == null ? '0' : '1',
      order.shippingReceiptUrl ?? '',
    ].join('|');
  }

  void _queueNewOrderAnnouncement(OrderData order) {
    _voiceQueue.add(
      _VoiceEvent(
        key: 'new-${order.id}',
        priority: 4,
        text: _newOrderVoice(order),
        orderId: order.id,
        type: _HighlightType.newOrder,
      ),
    );
  }

  void _queueStageAnnouncement(
      OrderData order,
      KeeperStage oldStage,
      KeeperStage newStage,
      ) {
    switch (newStage) {
      case KeeperStage.orderanMasuk:
      // Tidak ada voice tambahan saat order dikembalikan ke inbox.
        break;

      case KeeperStage.sedangDikerjakan:
        _voiceQueue.add(
          _VoiceEvent(
            key: 'start-${order.id}-${order.startedAt?.millisecondsSinceEpoch}',
            priority: 3,
            text: _startVoice(order),
            orderId: order.id,
            type: _HighlightType.inProgress,
          ),
        );
        break;

      case KeeperStage.inputResi:
        _voiceQueue.add(
          _VoiceEvent(
            key:
            'ready-${order.id}-${order.readyToShipAt?.millisecondsSinceEpoch}',
            priority: 2,
            text: _readyToShipVoice(order),
            orderId: order.id,
            type: _HighlightType.receipt,
          ),
        );
        break;

      case KeeperStage.selesaiDikerjakan:
        _voiceQueue.add(
          _VoiceEvent(
            key:
            'finish-${order.id}-${order.completedAt?.millisecondsSinceEpoch}',
            priority: 2,
            text: _finishVoice(order),
            orderId: order.id,
            type: _HighlightType.completed,
          ),
        );
        break;
    }
  }

  void _queueReceiptAnnouncement(OrderData order) {
    final key =
        'receipt-update-${order.id}-${_shippingEventSignature(order)}';

    final alreadyQueued = _voiceQueue.any((event) => event.key == key);
    if (alreadyQueued) return;

    _voiceQueue.add(
      _VoiceEvent(
        key: key,
        priority: 2,
        text: _receiptVoice(order),
        orderId: order.id,
        type: _HighlightType.receipt,
      ),
    );
  }

  String _brand(OrderData order) {
    if (order.workspaceId == 'lavanya_art') {
      return 'LAVANYA ART';
    }
    return 'HAREXA ART';
  }

  String _newOrderVoice(OrderData order) {
    return 'Pak Eman, ada order baru! '
        'Cek gambarnya segera! '
        'Order ${_brand(order)}, '
        'ukuran ${_speakText(order.ukuran)}, '
        'frame ${_speakText(order.frame)}, '
        'deadline ${_deadlineVoice(order)}. '
        'Gaskeun Pak Eman, cek gambarnya!';
  }

  String _startVoice(OrderData order) {
    return 'Pak Eman, order ${_brand(order)} '
        'ukuran ${_speakText(order.ukuran)} '
        'sudah mulai dikerjakan. '
        'Gaskeun!';
  }

  String _readyToShipVoice(OrderData order) {
    return 'Tim packing! Order ${_brand(order)} '
        'ukuran ${_speakText(order.ukuran)} '
        'sudah siap dikirim dan masuk tahap input resi. '
        'Silakan cek order dan siapkan packing!';
  }

  String _finishVoice(OrderData order) {
    return 'Tim packing! Order ${_brand(order)} '
        'dengan ukuran ${_speakText(order.ukuran)}, '
        'frame ${_speakText(order.frame)} '
        'sudah selesai. '
        'Segera pasang frame dan packing! '
        'Gaskeun barudak!';
  }

  String _receiptVoice(OrderData order) {
    return 'Informasi tim packing! '
        'Hasil resi order ${_brand(order)} '
        'ukuran ${_speakText(order.ukuran)} '
        'sudah diinput. '
        'Silakan cek resinya di monitor.';
  }

  String _deadlineWarningVoice(OrderData order) {
    return 'Pak Eman, perhatian! '
        'Order ${_brand(order)} '
        'dengan ukuran ${_speakText(order.ukuran)} '
        'akan masuk deadline besok. '
        'Harap segera diselesaikan atau input resi terlebih dahulu. '
        'Jangan sampai terlambat!';
  }

  String _speakText(String value) => value.replaceAll('×', ' kali ');

  String _deadlineVoice(OrderData order) {
    final remaining = _deadlineRemaining(order);
    if (remaining.isNegative) return 'sudah terlambat';
    if (remaining.inHours < 24) return 'kurang dari satu hari';
    final days = remaining.inDays;
    return '$days hari';
  }

  void _processVoiceQueue() {
    if (!_voiceEnabled || _speaking || _voiceQueue.isEmpty) return;

    _voiceQueue.sort((a, b) => a.priority.compareTo(b.priority));

    // Buang duplikasi event yang sama sebelum berbicara.
    final first = _voiceQueue.removeAt(0);
    _voiceQueue.removeWhere((event) => event.key == first.key);

    _speak(first);
  }

  void _speak(_VoiceEvent event) {
    _speaking = true;

    if (mounted) {
      setState(() {
        _highlightOrderId = event.orderId;
        _highlightType = event.type;
        _lastAnnouncement = event.text;
        _lastAnnouncementAt = DateTime.now();
      });
    }

    final utterance = html.SpeechSynthesisUtterance(event.text)
      ..lang = 'id-ID'
      ..rate = 1.08
      ..pitch = 1.0
      ..volume = 1.0;

    utterance.onEnd.listen((_) {
      _speaking = false;

      if (mounted) {
        setState(() {
          _highlightOrderId = null;
          _highlightType = _HighlightType.none;
        });
      }

      Future<void>.delayed(
        const Duration(milliseconds: 250),
        _processVoiceQueue,
      );
    });

    utterance.onError.listen((_) {
      _speaking = false;
      if (mounted) {
        setState(() {
          _highlightOrderId = null;
          _highlightType = _HighlightType.none;
        });
      }
      Future<void>.delayed(
        const Duration(milliseconds: 250),
        _processVoiceQueue,
      );
    });

    final synthesis = html.window.speechSynthesis;
    if (synthesis == null) {
      _speaking = false;
      if (mounted) {
        setState(() {
          _highlightOrderId = null;
          _highlightType = _HighlightType.none;
        });
      }
      Future<void>.delayed(
        const Duration(milliseconds: 250),
        _processVoiceQueue,
      );
      return;
    }

    synthesis.cancel();
    synthesis.speak(utterance);
  }

  void _stopBrowserSpeech() {
    try {
      html.window.speechSynthesis?.cancel();
    } catch (_) {}
  }

  void _unlockMobileSpeech() {
    final synthesis = html.window.speechSynthesis;
    if (synthesis == null) return;

    try {
      // Mobile Chrome/Safari can block speech until the browser receives a
      // direct user gesture. This short announcement is triggered only by
      // the Voice button, so the existing realtime voice queue remains
      // unchanged and desktop behavior stays the same.
      synthesis.cancel();

      final unlockUtterance = html.SpeechSynthesisUtterance(
        'Voice monitor aktif.',
      )
        ..lang = 'id-ID'
        ..rate = 1.0
        ..pitch = 1.0
        ..volume = 1.0;

      unlockUtterance.onEnd.listen((_) {
        _processVoiceQueue();
      });

      unlockUtterance.onError.listen((_) {
        _processVoiceQueue();
      });

      synthesis.speak(unlockUtterance);
    } catch (_) {
      _processVoiceQueue();
    }
  }

  void _toggleVoice() {
    setState(() {
      _voiceEnabled = !_voiceEnabled;
    });

    if (!_voiceEnabled) {
      _voiceQueue.clear();
      _stopBrowserSpeech();
      _speaking = false;
    } else {
      // The button tap itself is a trusted mobile user gesture. Use it to
      // unlock the browser SpeechSynthesis engine before processing events.
      _unlockMobileSpeech();
    }
  }

  DateTime _finishDate(OrderData order) {
    return order.createdAt.add(
      Duration(days: order.deadlineDays),
    );
  }

  Duration _deadlineRemaining(OrderData order) {
    return _finishDate(order).difference(_now);
  }

  _DeadlineLevel _deadlineLevel(OrderData order) {
    final remaining = _deadlineRemaining(order);

    if (order.completedAt != null ||
        order.keeperStage == KeeperStage.selesaiDikerjakan) {
      return _DeadlineLevel.completed;
    }

    if (remaining.isNegative) return _DeadlineLevel.late;
    if (remaining.inHours <= 24) return _DeadlineLevel.tomorrow;
    if (remaining.inHours <= 48) return _DeadlineLevel.watch;
    return _DeadlineLevel.safe;
  }

  String _deadlineLabel(OrderData order) {
    final level = _deadlineLevel(order);
    switch (level) {
      case _DeadlineLevel.safe:
        return 'AMAN';
      case _DeadlineLevel.watch:
        return 'PANTAU';
      case _DeadlineLevel.tomorrow:
        return 'DEADLINE BESOK';
      case _DeadlineLevel.late:
        return 'TERLAMBAT';
      case _DeadlineLevel.completed:
        return 'SELESAI';
    }
  }

  Color _deadlineColor(_DeadlineLevel level) {
    switch (level) {
      case _DeadlineLevel.safe:
        return const Color(0xFF4FB477);
      case _DeadlineLevel.watch:
        return const Color(0xFFE0B95F);
      case _DeadlineLevel.tomorrow:
        return const Color(0xFFE58B45);
      case _DeadlineLevel.late:
        return const Color(0xFFE25555);
      case _DeadlineLevel.completed:
        return const Color(0xFF55B6A5);
    }
  }

  void _checkDeadlineAnnouncements() {
    for (final order in _activeOrders) {
      if (order.completedAt != null ||
          order.keeperStage == KeeperStage.selesaiDikerjakan) {
        continue;
      }

      final remaining = _deadlineRemaining(order);
      final deadline = _finishDate(order);

      final bool isLate = remaining.isNegative;
      final bool isTomorrow =
          !remaining.isNegative && remaining.inHours <= 24;

      if (!isLate && !isTomorrow) {
        continue;
      }

      final levelKey = isLate ? 'late' : 'tomorrow';
      final key =
          'deadline-${order.id}-$levelKey-${deadline.year}-${deadline.month}-${deadline.day}';

      final alreadyQueued = _voiceQueue.any((event) => event.key == key);
      final alreadyAnnounced = _deadlineAnnouncedKeys.contains(key);

      if (!alreadyQueued && !alreadyAnnounced) {
        _deadlineAnnouncedKeys.add(key);

        _voiceQueue.add(
          _VoiceEvent(
            key: key,
            priority: isLate ? 0 : 1,
            text: isLate
                ? _lateDeadlineVoice(order)
                : _deadlineWarningVoice(order),
            orderId: order.id,
            type: _HighlightType.deadline,
          ),
        );
      }
    }

    _processVoiceQueue();
  }

  String _lateDeadlineVoice(OrderData order) {
    return 'PAK EMAN! PERHATIAN! '
        'Order ${_brand(order)} '
        'ukuran ${_speakText(order.ukuran)} '
        'SUDAH TERLAMBAT! '
        'Harap segera diselesaikan dan koordinasikan ke tim packing! '
        'Jangan sampai order tertinggal!';
  }

  List<OrderData> get _activeOrders {
    // Conveyor hanya berisi pekerjaan yang BELUM SELESAI.
    // Begitu Keeper menyelesaikan order, order keluar dari conveyor
    // agar layar tidak penuh. Riwayat tetap berada di OrderStore.
    return _orders
        .where(
          (order) =>
      order.completedAt == null &&
          order.keeperStage != KeeperStage.selesaiDikerjakan,
    )
        .toList();
  }

  List<OrderData> _laneOrders(String workspaceId) {
    final list = _activeOrders
        .where((order) => order.workspaceId == workspaceId)
        .toList();

    list.sort((a, b) {
      final deadlineCompare =
      _finishDate(a).compareTo(_finishDate(b));
      if (deadlineCompare != 0) return deadlineCompare;

      final stageCompare =
      _stagePriority(a.keeperStage).compareTo(
        _stagePriority(b.keeperStage),
      );
      if (stageCompare != 0) return stageCompare;

      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  int _stagePriority(KeeperStage stage) {
    switch (stage) {
      case KeeperStage.orderanMasuk:
        return 0;
      case KeeperStage.sedangDikerjakan:
        return 1;
      case KeeperStage.inputResi:
        return 2;
      case KeeperStage.selesaiDikerjakan:
        return 3;
    }
  }

  String _stageLabel(KeeperStage stage) {
    switch (stage) {
      case KeeperStage.orderanMasuk:
        return 'ORDER BARU';
      case KeeperStage.sedangDikerjakan:
        return 'SEDANG DIKERJAKAN';
      case KeeperStage.inputResi:
        return 'SIAP DIKIRIM';
      case KeeperStage.selesaiDikerjakan:
        return 'SELESAI';
    }
  }

  Color _stageColor(KeeperStage stage) {
    switch (stage) {
      case KeeperStage.orderanMasuk:
        return const Color(0xFF4C8DFF);
      case KeeperStage.sedangDikerjakan:
        return const Color(0xFFE0B95F);
      case KeeperStage.inputResi:
        return const Color(0xFFE28C4D);
      case KeeperStage.selesaiDikerjakan:
        return const Color(0xFF55B477);
    }
  }

  int _completedToday() {
    return _orders.where((order) {
      final value = order.completedAt;
      if (value == null) return false;
      return _sameDay(value, _now);
    }).length;
  }

  int _completedThisWeek() {
    final monday =
    DateTime(_now.year, _now.month, _now.day)
        .subtract(Duration(days: _now.weekday - 1));

    return _orders.where((order) {
      final value = order.completedAt;
      if (value == null) return false;
      return !value.isBefore(monday) &&
          value.isBefore(monday.add(const Duration(days: 7)));
    }).length;
  }

  int _completedThisMonth() {
    return _orders.where((order) {
      final value = order.completedAt;
      if (value == null) return false;
      return value.year == _now.year &&
          value.month == _now.month;
    }).length;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  int _countWorkspace(String workspaceId) {
    return _activeOrders
        .where((order) => order.workspaceId == workspaceId)
        .length;
  }

  int _countStage(KeeperStage stage) {
    return _activeOrders
        .where((order) => order.keeperStage == stage)
        .length;
  }

  int _countDeadline(_DeadlineLevel level) {
    return _activeOrders
        .where((order) => _deadlineLevel(order) == level)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    _checkDeadlineAnnouncements();

    final harexa = _laneOrders('harexaart');
    final lavanya = _laneOrders('lavanya_art');

    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                _buildTopBar(),
                _buildStatsBar(),
                _buildAttendanceBar(),
                Expanded(
                  child: _buildLiveBoard(
                    constraints,
                    harexa,
                    lavanya,
                  ),
                ),
                _buildBottomStatusBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 1050;
        final mobile = width < 700;

        return Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : compact ? 14 : 22, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0E1014),
            border: Border(bottom: BorderSide(color: Color(0xFF242830))),
          ),
          child: mobile
              ? Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF191C21),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFF30343C)),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: Color(0xFFD9B55F), size: 21),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'HAREXAART • LIVE MONITOR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8),
                ),
              ),
              IconButton(
                tooltip: _voiceEnabled ? 'Matikan voice' : 'Aktifkan voice',
                onPressed: _toggleVoice,
                icon: Icon(
                  _voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _voiceEnabled ? const Color(0xFF65C58A) : const Color(0xFF737983),
                  size: 21,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu monitoring',
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFB7BDC5)),
                onSelected: (value) {
                  if (value == 'packing') _showPackingQueue();
                  if (value == 'archive') _showArchive();
                  if (value == 'attendance') _showAttendanceOverview();
                  if (value == 'absent') _showAttendanceDialog(startAbsent: true);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'attendance', child: Text('ABSEN • ${_attendanceRecords.length}')),
                  const PopupMenuItem(value: 'absent', child: Text('TIDAK KERJA')),
                  PopupMenuItem(value: 'packing', child: Text('SELESAI • ${_packingReadyOrders.length}')),
                  PopupMenuItem(value: 'archive', child: Text('ARSIP • ${_archiveOrders.length}')),
                ],
              ),
            ],
          )
              : Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF191C21),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF30343C)),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: Color(0xFFD9B55F), size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('HAREXAART', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.7)),
                    SizedBox(height: 3),
                    Text('LIVE OPERATION MONITOR', style: TextStyle(color: Color(0xFF777D87), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  ],
                ),
              ),
              _livePill(),
              if (!compact) const SizedBox(width: 12),
              _clockPill(),
              if (!compact) ...[
                const SizedBox(width: 10),
                _speedControl(),
              ],
              const SizedBox(width: 8),
              _topBarAttendanceAction(
                label: compact ? 'ABSEN' : 'ABSEN',
                count: _attendanceRecords.length,
                onTap: _showAttendanceOverview,
              ),
              const SizedBox(width: 7),
              _topBarAction(icon: Icons.inventory_2_outlined, label: compact ? 'DONE' : 'SELESAI', count: _packingReadyOrders.length, onTap: _showPackingQueue),
              const SizedBox(width: 7),
              _topBarAction(icon: Icons.archive_outlined, label: compact ? 'ARSIP' : 'ARSIP', count: _archiveOrders.length, onTap: _showArchive),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _voiceEnabled ? 'Matikan voice' : 'Aktifkan voice',
                onPressed: _toggleVoice,
                icon: Icon(_voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: _voiceEnabled ? const Color(0xFF65C58A) : const Color(0xFF737983)),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _topBarAttendanceAction({
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Absensi hari ini',
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(
          Icons.how_to_reg_rounded,
          size: 14,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFF19A3E),
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2816),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFF19A3E),
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF19A3E),
          side: const BorderSide(
            color: Color(0xFF7B5227),
          ),
          backgroundColor: const Color(0xFF1D1710),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _topBarAction({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF23272E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFCFD3D8),
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB7BDC5),
          side: const BorderSide(color: Color(0xFF30353D)),
          backgroundColor: const Color(0xFF14171C),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  List<OrderData> get _packingReadyOrders {
    final list = _orders
        .where((order) =>
    order.status == OrderStatus.selesai &&
        order.keeperStage == KeeperStage.selesaiDikerjakan &&
        order.packingStatus == PackingStatus.belumDipacking)
        .toList();

    list.sort((a, b) {
      final ad = a.completedAt ?? a.createdAt;
      final bd = b.completedAt ?? b.createdAt;
      return bd.compareTo(ad);
    });
    return list;
  }

  List<OrderData> get _archiveOrders {
    return _orders
        .where((order) =>
    order.packingStatus == PackingStatus.sudahDipacking ||
        order.packingStatus == PackingStatus.sudahDikirim)
        .toList()
      ..sort((a, b) {
        final ad = a.packedAt ?? a.shippedAt ?? a.completedAt ?? a.createdAt;
        final bd = b.packedAt ?? b.shippedAt ?? b.completedAt ?? b.createdAt;
        return bd.compareTo(ad);
      });
  }

  List<OrderData> _filteredArchiveOrders() {
    final now = DateTime.now();
    final archive = _archiveOrders;

    switch (_archiveRange) {
      case _ArchiveRange.today:
        return archive
            .where((order) => _sameDay(_archiveDate(order), now))
            .toList();
      case _ArchiveRange.week:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return archive.where((order) {
          final value = _archiveDate(order);
          return !value.isBefore(start) && value.isBefore(end);
        }).toList();
      case _ArchiveRange.month:
        return archive
            .where((order) {
          final value = _archiveDate(order);
          return value.year == now.year && value.month == now.month;
        })
            .toList();
      case _ArchiveRange.custom:
        if (_archiveCustomStart == null || _archiveCustomEnd == null) {
          return <OrderData>[];
        }
        final start = DateTime(
          _archiveCustomStart!.year,
          _archiveCustomStart!.month,
          _archiveCustomStart!.day,
        );
        final end = DateTime(
          _archiveCustomEnd!.year,
          _archiveCustomEnd!.month,
          _archiveCustomEnd!.day,
        ).add(const Duration(days: 1));
        return archive.where((order) {
          final value = _archiveDate(order);
          return !value.isBefore(start) && value.isBefore(end);
        }).toList();
    }
  }

  DateTime _archiveDate(OrderData order) {
    return order.packedAt ?? order.shippedAt ?? order.completedAt ?? order.createdAt;
  }

  Widget _speedControl() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2A2E36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Perlambat order flow',
            onPressed: () {
              setState(() {
                _scrollSpeed =
                    (_scrollSpeed - 0.15).clamp(0.25, 3.0);
              });
            },
            icon: const Icon(
              Icons.remove_rounded,
              size: 15,
              color: Color(0xFF858B94),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 27,
              minHeight: 27,
            ),
          ),
          Text(
            '${_scrollSpeed.toStringAsFixed(2)}x',
            style: const TextStyle(
              color: Color(0xFFD2D5DA),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          IconButton(
            tooltip: 'Percepat order flow',
            onPressed: () {
              setState(() {
                _scrollSpeed =
                    (_scrollSpeed + 0.15).clamp(0.25, 3.0);
              });
            },
            icon: const Icon(
              Icons.add_rounded,
              size: 15,
              color: Color(0xFFD0AD5B),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 27,
              minHeight: 27,
            ),
          ),
          const SizedBox(width: 2),
          Tooltip(
            message: 'Reset ke 1.35x',
            child: InkWell(
              onTap: () => setState(() => _scrollSpeed = 1.35),
              borderRadius: BorderRadius.circular(15),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 13,
                  color: Color(0xFF727984),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _livePill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF121B17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF294436),
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 4,
            backgroundColor: Color(0xFF5BC685),
          ),
          SizedBox(width: 7),
          Text(
            'LIVE',
            style: TextStyle(
              color: Color(0xFF86D9A5),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clockPill() {
    final h = _two(_now.hour);
    final m = _two(_now.minute);
    final s = _two(_now.second);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2A2E36),
        ),
      ),
      child: Text(
        '$h:$m:$s',
        style: const TextStyle(
          color: Color(0xFFC8CBD0),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    const metrics = <Map<String, Object>>[
      {'label': 'AKTIF', 'icon': Icons.bolt_rounded},
      {'label': 'HAREXA', 'icon': Icons.auto_awesome_outlined},
      {'label': 'LAVANYA', 'icon': Icons.palette_outlined},
      {'label': 'BARU', 'icon': Icons.fiber_new_rounded},
      {'label': 'PRODUKSI', 'icon': Icons.autorenew_rounded},
      {'label': 'READY', 'icon': Icons.local_shipping_outlined},
      {'label': 'H-1', 'icon': Icons.warning_amber_rounded},
      {'label': 'HARI INI', 'icon': Icons.check_circle_outline_rounded},
      {'label': 'MINGGU', 'icon': Icons.date_range_outlined},
      {'label': 'BULAN', 'icon': Icons.calendar_month_outlined},
    ];

    final values = <String>[
      '${_activeOrders.length}', '${_countWorkspace('harexaart')}', '${_countWorkspace('lavanya_art')}',
      '${_countStage(KeeperStage.orderanMasuk)}', '${_countStage(KeeperStage.sedangDikerjakan)}', '${_countStage(KeeperStage.inputResi)}',
      '${_countDeadline(_DeadlineLevel.tomorrow)}', '${_completedToday()}', '${_completedThisWeek()}', '${_completedThisMonth()}',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 650;
        final compact = constraints.maxWidth < 1000;
        return Container(
          constraints: BoxConstraints(minHeight: mobile ? 82 : 92),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 18, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0B0D10),
            border: Border(bottom: BorderSide(color: Color(0xFF1E2229))),
          ),
          child: mobile
              ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(metrics.length, (i) => SizedBox(width: 112, child: _metric(metrics[i]['label']! as String, values[i], metrics[i]['icon']! as IconData)))),
          )
              : Row(children: List.generate(metrics.length, (i) => Expanded(child: _metric(metrics[i]['label']! as String, values[i], metrics[i]['icon']! as IconData, compact: compact)))),
        );
      },
    );
  }

  Widget _metric(String label, String value, IconData icon, {bool compact = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10),
      decoration: BoxDecoration(color: const Color(0xFF101318), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF20242B))),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF777E88), size: compact ? 15 : 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: const Color(0xFF626872), fontSize: compact ? 6 : 7, fontWeight: FontWeight.w800, letterSpacing: .6)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: Colors.white, fontSize: compact ? 14 : 15, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLiveBoard(BoxConstraints constraints, List<OrderData> harexa, List<OrderData> lavanya) {
    final mobile = constraints.maxWidth < 850;
    final compact = constraints.maxWidth < 1150;
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 6 : compact ? 8 : 12, 8, mobile ? 6 : compact ? 8 : 12, 6),
      child: mobile
          ? Column(
        children: [
          Expanded(child: _buildBrandLane(title: 'LAVANYA ART', subtitle: '${lavanya.length} ORDER', icon: Icons.palette_rounded, orders: lavanya, compact: true, mobile: true)),
          const SizedBox(height: 8),
          Expanded(child: _buildBrandLane(title: 'HAREXA ART', subtitle: '${harexa.length} ORDER', icon: Icons.auto_awesome_rounded, orders: harexa, compact: true, mobile: true)),
        ],
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildBrandLane(title: 'LAVANYA ART', subtitle: '${lavanya.length} ORDER', icon: Icons.palette_rounded, orders: lavanya, compact: compact, mobile: false)),
          const SizedBox(width: 9),
          Expanded(child: _buildBrandLane(title: 'HAREXA ART', subtitle: '${harexa.length} ORDER', icon: Icons.auto_awesome_rounded, orders: harexa, compact: compact, mobile: false)),
        ],
      ),
    );
  }

  Widget _buildBrandLane({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<OrderData> orders,
    required bool compact,
    bool mobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F13),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF292E36)),
      ),
      child: Column(
        children: [
          _buildLaneHeader(title: title, subtitle: subtitle, icon: icon),
          Expanded(
            child: _LiveOrderLane(
              orders: orders,
              speedMultiplier: _scrollSpeed,
              itemBuilder: (order) => _buildOrderTile(order, compact: compact, mobile: mobile),
              emptyMessage: title == 'HAREXA ART' ? 'BELUM ADA ORDER HAREXA ART' : 'BELUM ADA ORDER LAVANYA ART',
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLaneHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111419),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFF2A2F37),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFD9B55F),
            size: 18,
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF20242A),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8B919A),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'LIVE ORDER FLOW',
            style: TextStyle(
              color: Color(0xFF555B65),
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(OrderData order, {bool compact = false, bool mobile = false}) {
    final deadlineLevel = _deadlineLevel(order);
    final stageColor = _stageColor(order.keeperStage);
    final isHighlighted = _highlightOrderId == order.id;
    final content = mobile
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductPreview(order, compact: true),
            const SizedBox(width: 9),
            Expanded(child: _buildOrderInformation(order, stageColor, deadlineLevel)),
          ],
        ),
        const SizedBox(height: 9),
        _buildActionColumn(order, compact: true),
      ],
    )
        : Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductPreview(order, compact: compact),
        SizedBox(width: compact ? 7 : 11),
        Expanded(child: _buildOrderInformation(order, stageColor, deadlineLevel)),
        SizedBox(width: compact ? 6 : 10),
        _buildActionColumn(order, compact: compact),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(mobile ? 8 : 9),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF191C21) : const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: isHighlighted ? _highlightColor(_highlightType) : const Color(0xFF242830), width: isHighlighted ? 1.5 : 1),
        boxShadow: isHighlighted ? [BoxShadow(color: _highlightColor(_highlightType).withOpacity(.15), blurRadius: 16, spreadRadius: 1)] : const [],
      ),
      child: content,
    );
  }
  Widget _productImageContent(
      OrderData order, {
        BoxFit fit = BoxFit.cover,
      }) {
    final bytes = order.productImage;
    final url = order.productImageUrl?.trim();

    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF646A73),
            size: 25,
          ),
        ),
      );
    }

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF646A73),
            size: 25,
          ),
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF646A73),
        size: 25,
      ),
    );
  }

  Future<Uint8List?> _fetchMonitoringUrlBytes(String url) async {
    try {
      final request = await html.HttpRequest.request(
        url,
        method: 'GET',
        responseType: 'arraybuffer',
      );
      final response = request.response;
      if (response is ByteBuffer) {
        return Uint8List.view(response);
      }
      if (response is Uint8List) {
        return response;
      }
    } catch (error) {
      debugPrint('MONITORING FILE FETCH GAGAL: $error');
    }
    return null;
  }

  Widget _buildProductPreview(OrderData order, {bool compact = false}) {
    return InkWell(
      onTap: () => _showProductImage(order),
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(
            width: compact ? 70 : 92,
            height: compact ? 70 : 92,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF2C3139),
              ),
            ),
            child: _productImageContent(order),
          ),
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.72),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: Colors.white,
                    size: 11,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'REVIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInformation(
      OrderData order,
      Color stageColor,
      _DeadlineLevel deadlineLevel,
      ) {
    final remaining = _deadlineRemaining(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: stageColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: stageColor.withOpacity(.28),
                ),
              ),
              child: Text(
                _stageLabel(order.keeperStage),
                style: TextStyle(
                  color: stageColor,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              order.id,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
            const Spacer(),
            _deadlineBadge(
              _deadlineLabel(order),
              _deadlineColor(deadlineLevel),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                order.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD5D8DD),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              order.workspaceName,
              style: const TextStyle(
                color: Color(0xFF686E78),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            _infoChip(
              Icons.straighten_rounded,
              'UKURAN',
              order.ukuran,
            ),
            _infoChip(
              Icons.crop_square_rounded,
              'FRAME',
              order.frame,
            ),
            _infoChip(
              Icons.palette_outlined,
              'WARNA',
              'Belum tersedia',
              muted: true,
            ),
            _infoChip(
              Icons.timer_outlined,
              'DEADLINE',
              _formatDateTime(_finishDate(order)),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            _timeItem(
              'MASUK',
              _formatDateTime(order.createdAt),
            ),
            if (order.startedAt != null)
              _timeItem(
                'MULAI',
                _formatDateTime(order.startedAt!),
              ),
            if (order.readyToShipAt != null)
              _timeItem(
                'READY',
                _formatDateTime(order.readyToShipAt!),
              ),
            if (order.completedAt != null)
              _timeItem(
                'SELESAI',
                _formatDateTime(order.completedAt!),
              ),
            if (order.shippingDate != null)
              _timeItem(
                'RESI',
                _formatDateTime(order.shippingDate!),
              ),
            const Spacer(),
            _remainingText(
              remaining,
              deadlineLevel,
            ),
          ],
        ),
        if (order.catatan.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notes_rounded,
                color: Color(0xFF666C75),
                size: 13,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order.catatan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF858B94),
                    fontSize: 8,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _deadlineBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(.28),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _infoChip(
      IconData icon,
      String label,
      String value, {
        bool muted = false,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF272C33),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: muted
                ? const Color(0xFF565C65)
                : const Color(0xFF737A84),
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF5E646D),
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 105,
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted
                    ? const Color(0xFF626872)
                    : const Color(0xFFB7BBC1),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF535963),
              fontSize: 6,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF858B94),
              fontSize: 7,
              fontWeight: FontWeight.w600,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _remainingText(
      Duration remaining,
      _DeadlineLevel level,
      ) {
    if (level == _DeadlineLevel.completed) {
      return const Text(
        'SELESAI',
        style: TextStyle(
          color: Color(0xFF55B477),
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    final text = remaining.isNegative
        ? 'TERLAMBAT ${_durationText(remaining.abs())}'
        : 'SISA ${_durationText(remaining)}';

    return Text(
      text,
      style: TextStyle(
        color: _deadlineColor(level),
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: .2,
      ),
    );
  }

  Widget _buildActionColumn(OrderData order, {bool compact = false}) {
    return SizedBox(
      width: compact ? 220 : 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _actionButton(icon: Icons.image_outlined, label: 'REVIEW GAMBAR', onPressed: () => _showProductImage(order), primary: true)),
              const SizedBox(width: 6),
              Expanded(child: _actionButton(icon: Icons.receipt_long_outlined, label: 'LIHAT RESI', onPressed: () => _showReceipt(order), primary: false)),
            ],
          ),
          const SizedBox(height: 6),
          _actionButton(icon: Icons.open_in_new_rounded, label: 'DETAIL', onPressed: () => _showOrderDetail(order), primary: false),
        ],
      ),
    );
  }
  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool primary,
  }) {
    return SizedBox(
      height: 30,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 13,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: onPressed == null
              ? const Color(0xFF4E545D)
              : primary
              ? const Color(0xFFD9B55F)
              : const Color(0xFF9DA3AC),
          side: BorderSide(
            color: onPressed == null
                ? const Color(0xFF282D34)
                : primary
                ? const Color(0xFF5D4E2F)
                : const Color(0xFF30353D),
          ),
          backgroundColor: primary
              ? const Color(0xFF161714)
              : const Color(0xFF12151A),
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStatusBar() {
    final lastTime = _lastAnnouncementAt == null
        ? '--:--:--'
        : _formatTime(_lastAnnouncementAt!);

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F13),
        border: Border(
          top: BorderSide(color: Color(0xFF20242B)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _voiceEnabled
                ? Icons.record_voice_over_outlined
                : Icons.volume_off_outlined,
            color: _voiceEnabled
                ? const Color(0xFF68C58D)
                : const Color(0xFF666C75),
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            _voiceEnabled ? 'VOICE ACTIVE' : 'VOICE OFF',
            style: TextStyle(
              color: _voiceEnabled
                  ? const Color(0xFF80D2A0)
                  : const Color(0xFF666C75),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(width: 13),
          Container(
            width: 1,
            height: 18,
            color: const Color(0xFF2A2E35),
          ),
          const SizedBox(width: 13),
          Text(
            'LAST ANNOUNCEMENT $lastTime',
            style: const TextStyle(
              color: Color(0xFF555B64),
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _lastAnnouncement,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF858B94),
                fontSize: 8,
              ),
            ),
          ),
          if (_voiceQueue.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1710),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFF4A3D24),
                ),
              ),
              child: Text(
                'VOICE QUEUE ${_voiceQueue.length}',
                style: const TextStyle(
                  color: Color(0xFFD1AF5E),
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _highlightColor(_HighlightType type) {
    switch (type) {
      case _HighlightType.newOrder:
        return const Color(0xFF4C8DFF);
      case _HighlightType.inProgress:
        return const Color(0xFFE0B95F);
      case _HighlightType.completed:
        return const Color(0xFF55B477);
      case _HighlightType.receipt:
        return const Color(0xFFE28C4D);
      case _HighlightType.deadline:
        return const Color(0xFFE25555);
      case _HighlightType.attendance:
        return const Color(0xFFF19A3E);
      case _HighlightType.none:
        return const Color(0xFF333842);
    }
  }

  void _showProductImage(OrderData order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0E1014),
          insetPadding: const EdgeInsets.all(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1050,
              maxHeight: 780,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _dialogHeader(
                    title: 'REVIEW GAMBAR',
                    subtitle:
                    '${_brand(order)} • ${order.id}',
                    onClose: () =>
                        Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: (order.productImage != null && order.productImage!.isNotEmpty) ||
                        (order.productImageUrl?.trim().isNotEmpty ?? false)
                        ? InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: _productImageContent(
                        order,
                        fit: BoxFit.contain,
                      ),
                    )
                        : const Center(
                      child: Text(
                        'Gambar order belum tersedia.',
                        style: TextStyle(color: Color(0xFF777D86)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dialogInfoLine(
                    order,
                    includeReceipt: false,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _monitoringIsPdfBytes(Uint8List bytes) {
    if (bytes.length < 5) {
      return false;
    }

    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  String _monitoringReceiptMimeType(Uint8List bytes) {
    if (_monitoringIsPdfBytes(bytes)) {
      return 'application/pdf';
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 6) {
      final header = String.fromCharCodes(bytes.take(6));
      if (header == 'GIF87a' || header == 'GIF89a') {
        return 'image/gif';
      }
    }

    return 'application/octet-stream';
  }

  void _openMonitoringReceiptFile(Uint8List bytes) {
    final mimeType = _monitoringReceiptMimeType(bytes);
    final blob = html.Blob(<dynamic>[bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Buka PDF/gambar asli di tab browser. Ini sengaja tidak memakai
    // Image.memory untuk PDF, sehingga PDF tidak lagi memunculkan
    // ImageCodecException.
    html.window.open(url, '_blank');

    // Beri waktu browser membaca object URL sebelum URL dibersihkan.
    Future<void>.delayed(const Duration(minutes: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  void _showReceipt(OrderData order) {
    final receiptBytes = order.shippingReceiptImage;
    final receiptUrl = order.shippingReceiptUrl?.trim();

    if ((receiptBytes == null || receiptBytes.isEmpty) &&
        (receiptUrl == null || receiptUrl.isEmpty)) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF17191D),
            title: const Text(
              'RESI BELUM TERSEDIA',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Order ini belum memiliki file resi yang diinput.',
              style: TextStyle(color: Color(0xFFB8BDC5)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('TUTUP'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Jika data berasal dari Supabase Storage dan belum ada bytes lokal,
    // buka URL asli. Ini berlaku untuk PDF maupun gambar.
    if ((receiptBytes == null || receiptBytes.isEmpty) &&
        receiptUrl != null && receiptUrl.isNotEmpty) {
      html.window.open(receiptUrl, '_blank');
      return;
    }

    // PDF lokal: buka file PDF asli, jangan pernah masuk Image.memory.
    if (receiptBytes != null && _monitoringIsPdfBytes(receiptBytes)) {
      _openMonitoringReceiptFile(receiptBytes);
      return;
    }

    // JPG/PNG/GIF: tampilkan preview gambar di dialog.
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0E1014),
          insetPadding: const EdgeInsets.all(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 950,
              maxHeight: 780,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _dialogHeader(
                    title: 'HASIL RESI',
                    subtitle: '${_brand(order)} • ${order.id}',
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.memory(
                        receiptBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFF777D86),
                                  size: 48,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Format file tidak dapat ditampilkan sebagai gambar.',
                                  style: TextStyle(color: Color(0xFF777D86)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openMonitoringReceiptFile(receiptBytes),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('BUKA FILE'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dialogInfoLine(order, includeReceipt: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<int>?> _buildSelectedReceiptsPdf(
      List<OrderData> selectedOrders,
      ) async {
    final document = PdfDocument();
    PdfSection? section;
    bool addedAnyPage = false;

    try {
      for (final order in selectedOrders) {
        Uint8List? bytes = order.shippingReceiptImage;
        if (bytes == null || bytes.isEmpty) {
          final url = order.shippingReceiptUrl?.trim();
          if (url != null && url.isNotEmpty) {
            bytes = await _fetchMonitoringUrlBytes(url);
          }
        }
        if (bytes == null || bytes.isEmpty) continue;

        final isPdf = _monitoringIsPdfBytes(bytes);

        if (isPdf) {
          final loaded = PdfDocument(inputBytes: bytes);
          try {
            for (var index = 0; index < loaded.pages.count; index++) {
              final template = loaded.pages[index].createTemplate();
              if (section == null || section.pageSettings.size != template.size) {
                section = document.sections!.add();
                section.pageSettings.size = template.size;
                section.pageSettings.margins.all = 0;
              }
              section.pages.add().graphics.drawPdfTemplate(
                template,
                const Offset(0, 0),
              );
              addedAnyPage = true;
            }
          } finally {
            loaded.dispose();
          }
        } else {
          // JPG/PNG resi juga bisa ikut batch print. Satu gambar = satu halaman.
          final bitmap = PdfBitmap(bytes);
          if (section == null) {
            section = document.sections!.add();
            section.pageSettings.size = PdfPageSize.a4;
            section.pageSettings.margins.all = 0;
          }
          final page = section.pages.add();
          final client = page.getClientSize();
          final imageWidth = bitmap.width.toDouble();
          final imageHeight = bitmap.height.toDouble();
          final scale = imageWidth <= 0 || imageHeight <= 0
              ? 1.0
              : (client.width / imageWidth)
              .clamp(0.01, client.height / imageHeight);
          final drawWidth = imageWidth * scale;
          final drawHeight = imageHeight * scale;
          final left = (client.width - drawWidth) / 2;
          final top = (client.height - drawHeight) / 2;
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(left, top, drawWidth, drawHeight),
          );
          addedAnyPage = true;
        }
      }

      if (!addedAnyPage) {
        return null;
      }

      final bytes = await document.save();
      return bytes;
    } finally {
      document.dispose();
    }
  }

  void _showPackingQueue() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0F1216),
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final ready = _packingReadyOrders;
                final selected = ready
                    .where((order) => _selectedPackingOrderIds.contains(order.id))
                    .toList();

                // Bersihkan selection untuk order yang sudah tidak lagi berada
                // di antrean SELESAI.
                final readyIds = ready.map((order) => order.id).toSet();
                _selectedPackingOrderIds.removeWhere(
                      (id) => !readyIds.contains(id),
                );

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF55B477),
                            size: 21,
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SELESAI — SEGERA PACKING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Pilih satu, beberapa, atau semua resi untuk direview dan dicetak sekaligus.',
                                  style: TextStyle(
                                    color: Color(0xFF707781),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF142018),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2D543C),
                              ),
                            ),
                            child: Text(
                              '${ready.length} ORDER',
                              style: const TextStyle(
                                color: Color(0xFF7FD49A),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF858B94),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (ready.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15181D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF2A3038),
                            ),
                          ),
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedPackingOrderIds
                                      ..clear()
                                      ..addAll(readyIds);
                                  });
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.select_all, size: 15),
                                label: const Text('PILIH SEMUA'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedPackingOrderIds.clear();
                                  });
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.deselect, size: 15),
                                label: const Text('BATAL PILIH'),
                              ),
                              ElevatedButton.icon(
                                onPressed: selected.isEmpty
                                    ? null
                                    : () => _reviewAndPrintSelectedReceipts(
                                  selected,
                                ),
                                icon: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  selected.isEmpty
                                      ? 'REVIEW + PRINT TERPILIH'
                                      : 'REVIEW + PRINT ${selected.length} RESI',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD9B55F),
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: selected.isEmpty
                                    ? null
                                    : () async {
                                  await _packSelectedOrders(selected);
                                  setDialogState(() {});
                                },
                                icon: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  selected.isEmpty
                                      ? 'PACKING TERPILIH'
                                      : 'PACKING ${selected.length} TERPILIH',
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: selected.isEmpty
                                    ? null
                                    : () async {
                                  await _reviewPrintAndPackSelected(
                                    selected,
                                  );
                                  setDialogState(() {});
                                },
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  selected.isEmpty
                                      ? 'PRINT + PACKING'
                                      : 'PRINT + PACKING ${selected.length}',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D5A37),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ready.isEmpty
                            ? const Center(
                          child: Text(
                            'SEMUA ORDER SELESAI SUDAH DIPACKING.',
                            style: TextStyle(
                              color: Color(0xFF69707A),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                            : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            itemCount: ready.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 7),
                            itemBuilder: (context, index) {
                              final order = ready[index];
                              return _buildPackingQueueRow(
                                order,
                                selected: _selectedPackingOrderIds
                                    .contains(order.id),
                                onSelectionChanged: (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedPackingOrderIds.add(order.id);
                                    } else {
                                      _selectedPackingOrderIds.remove(order.id);
                                    }
                                  });
                                  setDialogState(() {});
                                },
                                onChanged: () => setDialogState(() {}),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPackingQueueRow(
      OrderData order, {
        required bool selected,
        required ValueChanged<bool> onSelectionChanged,
        required VoidCallback onChanged,
      }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF1A1D18)
            : const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? const Color(0xFFD9B55F)
              : const Color(0xFF2A3038),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onSelectionChanged(value ?? false),
            activeColor: const Color(0xFFD9B55F),
            checkColor: Colors.black,
          ),
          InkWell(
            onTap: () => _showProductImage(order),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 76,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D22),
                borderRadius: BorderRadius.circular(7),
              ),
              child: order.productImage == null
                  ? const Icon(
                Icons.image_not_supported_outlined,
                color: Color(0xFF626973),
                size: 23,
              )
                  : Image.memory(order.productImage!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'SELESAI',
                      style: TextStyle(
                        color: Color(0xFF55B477),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        order.id,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_brand(order)} • ${order.productName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9BEC5),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _infoChip(Icons.straighten_rounded, 'UKURAN', order.ukuran),
                    _infoChip(Icons.crop_square_rounded, 'FRAME', order.frame),
                    _infoChip(
                      Icons.schedule_rounded,
                      'SELESAI',
                      order.completedAt == null
                          ? '-'
                          : _formatDateTime(order.completedAt!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 138,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.image_outlined,
                        label: 'REVIEW GAMBAR',
                        onPressed: () => _showProductImage(order),
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.receipt_long_outlined,
                        label: 'LIHAT RESI',
                        onPressed: () => _showReceipt(order),
                        primary: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmPacking(order, onChanged),
                    icon: const Icon(Icons.inventory_2_outlined, size: 15),
                    label: const Text(
                      'PACKING LANGSUNG',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D5A37),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewAndPrintSelectedReceipts(
      List<OrderData> selectedOrders,
      ) async {
    if (selectedOrders.isEmpty) return;

    final pdfBytes = await _buildSelectedReceiptsPdf(selectedOrders);
    if (pdfBytes == null || pdfBytes.isEmpty || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada file resi yang bisa dicetak.'),
          ),
        );
      }
      return;
    }

    // Review gabungan dibuka di tab baru agar operator bisa melihat semua
    // resi yang dipilih sebelum / sambil masuk ke dialog print browser.
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future<void>.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await Printing.layoutPdf(
      name: 'HarexaArt_Resi_${selectedOrders.length}_Order.pdf',
      onLayout: (_) async => Uint8List.fromList(pdfBytes),
    );

    OrderStore.instance.markReceiptsPrinted(
      orderIds: selectedOrders.map((order) => order.id).toList(),
    );

    if (mounted) setState(() {});
  }

  Future<void> _reviewPrintAndPackSelected(
      List<OrderData> selectedOrders,
      ) async {
    if (selectedOrders.isEmpty) return;

    await _reviewAndPrintSelectedReceipts(selectedOrders);
    if (!mounted) return;

    await _packSelectedOrders(selectedOrders);
  }

  Future<void> _packSelectedOrders(List<OrderData> selectedOrders) async {
    if (selectedOrders.isEmpty) return;

    final count = OrderStore.instance.markOrdersPacked(
      orderIds: selectedOrders.map((order) => order.id).toList(),
    );

    if (count > 0) {
      for (final order in selectedOrders) {
        _queuePackingVoice(order);
      }
      setState(() {
        _selectedPackingOrderIds.removeAll(
          selectedOrders.map((order) => order.id),
        );
      });
    }
  }

  Future<void> _confirmPacking(OrderData order, VoidCallback onChanged) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171A1F),
          title: const Text('KONFIRMASI PACKING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          content: Text(
            'Yakin order ${order.id} sudah benar dan siap dipacking langsung?\n\nSetelah dikonfirmasi, order akan keluar dari daftar SELESAI dan masuk ke ARSIP OPERASIONAL.',
            style: const TextStyle(color: Color(0xFFB2B7BF), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('YA, PACKING'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final ok = OrderStore.instance.markOrderPacked(
      orderId: order.id,
      workspaceId: order.workspaceId,
    );

    if (ok) {
      _queuePackingVoice(order);
      onChanged();
      setState(() {});
    }
  }

  void _queuePackingVoice(OrderData order) {
    final key = 'packed-${order.id}-${order.packedAt?.millisecondsSinceEpoch}';
    if (_voiceQueue.any((event) => event.key == key)) return;
    _voiceQueue.add(
      _VoiceEvent(
        key: key,
        priority: 2,
        text: 'TIM PACKING! Order ${_brand(order)} dengan ukuran ${_speakText(order.ukuran)}, frame ${_speakText(order.frame)} sudah dipacking. Siap diproses ke pengiriman! Gaskeun barudak!',
        orderId: order.id,
        type: _HighlightType.completed,
      ),
    );
    _processVoiceQueue();
  }

  Future<void> _showArchive() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0F1216),
          insetPadding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final archived = _filteredArchiveOrders();
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150, maxHeight: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.archive_outlined, color: Color(0xFFD9B55F), size: 21),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ARSIP OPERASIONAL', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                SizedBox(height: 3),
                                Text('Riwayat packing dan pengiriman. Data tidak dihapus dari sistem.', style: TextStyle(color: Color(0xFF707781), fontSize: 9)),
                              ],
                            ),
                          ),
                          Text('${archived.length} ORDER', style: const TextStyle(color: Color(0xFF9FA5AD), fontSize: 8, fontWeight: FontWeight.w900)),
                          IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close_rounded, color: Color(0xFF858B94))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildArchiveFilters(setDialogState),
                      const SizedBox(height: 12),
                      Expanded(
                        child: archived.isEmpty
                            ? const Center(child: Text('BELUM ADA ARSIP PADA PERIODE INI.', style: TextStyle(color: Color(0xFF686F79), fontSize: 10, fontWeight: FontWeight.w800)))
                            : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            itemCount: archived.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 7),
                            itemBuilder: (_, index) => _buildArchiveRow(archived[index], setDialogState),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildArchiveFilters(StateSetter setDialogState) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _archiveFilterButton('HARIAN', _ArchiveRange.today, setDialogState),
        _archiveFilterButton('MINGGUAN', _ArchiveRange.week, setDialogState),
        _archiveFilterButton('BULANAN', _ArchiveRange.month, setDialogState),
        _archiveFilterButton('CUSTOM', _ArchiveRange.custom, setDialogState),
        if (_archiveRange == _ArchiveRange.custom)
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: _archiveCustomStart != null && _archiveCustomEnd != null
                    ? DateTimeRange(start: _archiveCustomStart!, end: _archiveCustomEnd!)
                    : null,
              );
              if (picked == null) return;
              setState(() {
                _archiveCustomStart = picked.start;
                _archiveCustomEnd = picked.end;
              });
              setDialogState(() {});
            },
            icon: const Icon(Icons.date_range_outlined, size: 14),
            label: Text(
              _archiveCustomStart == null
                  ? 'PILIH RENTANG'
                  : '${_formatDate(_archiveCustomStart!)} - ${_formatDate(_archiveCustomEnd!)}',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }

  Widget _archiveFilterButton(String label, _ArchiveRange value, StateSetter setDialogState) {
    final active = _archiveRange == value;
    return OutlinedButton(
      onPressed: () {
        setState(() => _archiveRange = value);
        setDialogState(() {});
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? const Color(0xFFD9B55F) : const Color(0xFF858B94),
        side: BorderSide(color: active ? const Color(0xFF5D4E2F) : const Color(0xFF30353D)),
        backgroundColor: active ? const Color(0xFF191812) : const Color(0xFF14171C),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildArchiveRow(OrderData order, StateSetter setDialogState) {
    final sent = order.packingStatus == PackingStatus.sudahDikirim;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF292F37)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showProductImage(order),
            child: Container(
              width: 70,
              height: 70,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: const Color(0xFF1A1D22), borderRadius: BorderRadius.circular(7)),
              child: _productImageContent(order),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(order.id, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  _deadlineBadge(sent ? 'SUDAH DIKIRIM' : 'SUDAH PACKING', sent ? const Color(0xFF55B477) : const Color(0xFFD9B55F)),
                ]),
                const SizedBox(height: 5),
                Text('${_brand(order)} • ${order.productName}', style: const TextStyle(color: Color(0xFFAEB4BC), fontSize: 8, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _dialogSmallInfo('UKURAN', order.ukuran),
                  _dialogSmallInfo('FRAME', order.frame),
                  _dialogSmallInfo('PACKING', order.packedAt == null ? '-' : _formatDateTime(order.packedAt!)),
                  if (order.shippedAt != null) _dialogSmallInfo('DIKIRIM', _formatDateTime(order.shippedAt!)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Column(children: [
              _actionButton(icon: Icons.image_outlined, label: 'REVIEW GAMBAR', onPressed: () => _showProductImage(order), primary: true),
              const SizedBox(height: 5),
              _actionButton(icon: Icons.receipt_long_outlined, label: 'LIHAT RESI', onPressed: () => _showReceipt(order), primary: false),
              if (!sent) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmShipped(order, setDialogState),
                    icon: const Icon(Icons.local_shipping_outlined, size: 14),
                    label: const Text('SUDAH DIKIRIM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF174C59),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmShipped(OrderData order, StateSetter setDialogState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171A1F),
        title: const Text('KONFIRMASI PENGIRIMAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text('Yakin order ${order.id} sudah benar-benar dikirim?', style: const TextStyle(color: Color(0xFFB2B7BF))),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('BATAL')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('YA, SUDAH DIKIRIM')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = OrderStore.instance.markOrderShipped(
      orderId: order.id,
      workspaceId: order.workspaceId,
    );
    if (ok) {
      _queueShippedVoice(order);
      setDialogState(() {});
      setState(() {});
    }
  }

  void _queueShippedVoice(OrderData order) {
    final key = 'shipped-${order.id}-${order.shippedAt?.millisecondsSinceEpoch}';
    if (_voiceQueue.any((event) => event.key == key)) return;
    _voiceQueue.add(_VoiceEvent(
      key: key,
      priority: 2,
      text: 'Tim packing! Order ${_brand(order)} dengan ukuran ${_speakText(order.ukuran)} sudah dikirim. Data pengiriman tersimpan di arsip. Gaskeun!',
      orderId: order.id,
      type: _HighlightType.receipt,
    ));
    _processVoiceQueue();
  }

  void _showOrderDetail(OrderData order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF101216),
          insetPadding: const EdgeInsets.all(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 850,
              maxHeight: 720,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogHeader(
                    title: 'DETAIL ORDER',
                    subtitle:
                    '${_brand(order)} • ${order.id}',
                    onClose: () =>
                        Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _buildDialogThumb(order),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _detailTitle(
                                        'PRODUK',
                                        order.productName,
                                      ),
                                      _detailTitle(
                                        'UKURAN',
                                        order.ukuran,
                                      ),
                                      _detailTitle(
                                        'WARNA',
                                        'Belum tersedia di OrderData',
                                      ),
                                      _detailTitle(
                                        'FRAME',
                                        order.frame,
                                      ),
                                      _detailTitle(
                                        'STATUS',
                                        _stageLabel(
                                          order.keeperStage,
                                        ),
                                      ),
                                      _detailTitle(
                                        'DEADLINE',
                                        '${_formatDateTime(_finishDate(order))} • ${_deadlineLabel(order)}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _detailSection(
                              'TIMELINE',
                              [
                                _detailTitle(
                                  'ORDER MASUK',
                                  _formatDateTime(
                                    order.createdAt,
                                  ),
                                ),
                                _detailTitle(
                                  'MULAI',
                                  order.startedAt == null
                                      ? 'Belum mulai'
                                      : _formatDateTime(
                                    order.startedAt!,
                                  ),
                                ),
                                _detailTitle(
                                  'SIAP DIKIRIM',
                                  order.readyToShipAt == null
                                      ? 'Belum'
                                      : _formatDateTime(
                                    order.readyToShipAt!,
                                  ),
                                ),
                                _detailTitle(
                                  'SELESAI',
                                  order.completedAt == null
                                      ? 'Belum'
                                      : _formatDateTime(
                                    order.completedAt!,
                                  ),
                                ),
                                _detailTitle(
                                  'RESI',
                                  order.shippingDate == null
                                      ? 'Belum input'
                                      : _formatDateTime(
                                    order.shippingDate!,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _detailSection(
                              'CATATAN',
                              [
                                Text(
                                  order.catatan.trim().isEmpty
                                      ? 'Tidak ada catatan.'
                                      : order.catatan,
                                  style: const TextStyle(
                                    color: Color(0xFFA1A6AE),
                                    fontSize: 11,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _detailAction(
                                    icon: Icons.image_outlined,
                                    label: 'REVIEW GAMBAR',
                                    onTap: () {
                                      Navigator.of(
                                        dialogContext,
                                      ).pop();
                                      _showProductImage(
                                        order,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _detailAction(
                                    icon:
                                    Icons.receipt_long_outlined,
                                    label: 'LIHAT RESI',
                                    onTap: () {
                                      Navigator.of(
                                        dialogContext,
                                      ).pop();
                                      _showReceipt(
                                        order,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _dialogHeader({
    required String title,
    required String subtitle,
    required VoidCallback onClose,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF707680),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFF8A9099),
          ),
        ),
      ],
    );
  }

  Widget _dialogInfoLine(
      OrderData order, {
        required bool includeReceipt,
      }) {
    return Wrap(
      spacing: 14,
      runSpacing: 7,
      children: [
        _dialogSmallInfo('UKURAN', order.ukuran),
        _dialogSmallInfo('FRAME', order.frame),
        _dialogSmallInfo(
          'WARNA',
          'Belum tersedia',
        ),
        _dialogSmallInfo(
          'DEADLINE',
          _formatDateTime(_finishDate(order)),
        ),
        if (includeReceipt)
          _dialogSmallInfo(
            'KURIR',
            order.shippingCourier ?? '-',
          ),
      ],
    );
  }

  Widget _dialogSmallInfo(
      String label,
      String value,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF2A2F37),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                color: Color(0xFF606670),
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFFB9BDC4),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogThumb(OrderData order) {
    return Container(
      width: 190,
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF191C21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF30353D),
        ),
      ),
      child: _productImageContent(order, fit: BoxFit.contain),
    );
  }

  Widget _detailSection(
      String title,
      List<Widget> children,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF292E36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD0AC59),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .9,
            ),
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }

  Widget _detailTitle(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5E646D),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFB8BDC5),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(38),
        foregroundColor: onTap == null
            ? const Color(0xFF555B64)
            : const Color(0xFFD0AD5B),
        side: BorderSide(
          color: onTap == null
              ? const Color(0xFF292E35)
              : const Color(0xFF5C4C2B),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _formatDateTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')} '
        '${_formatTime(value)}';
  }

  String _formatTime(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _durationText(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours.remainder(24);
      return '${days}H ${hours}J';
    }

    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '${hours}J ${minutes}M';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}M ${seconds}D';
  }
}


/// Lane auto-scroll mandiri. User tidak perlu melakukan scroll manual.
/// Ketika sudah mencapai bagian bawah, lane berhenti sebentar lalu
/// kembali ke atas dan mengulang seperti conveyor/film order.
class _LiveOrderLane extends StatefulWidget {
  const _LiveOrderLane({
    required this.orders,
    required this.speedMultiplier,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final List<OrderData> orders;
  final double speedMultiplier;
  final Widget Function(OrderData order) itemBuilder;
  final String emptyMessage;

  @override
  State<_LiveOrderLane> createState() => _LiveOrderLaneState();
}

class _LiveOrderLaneState extends State<_LiveOrderLane> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  Timer? _resumeTimer;
  bool _pauseAtBottom = false;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _LiveOrderLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders.length != widget.orders.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.hasClients &&
            _controller.position.maxScrollExtent == 0) {
          _controller.jumpTo(0);
        }
      });
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 50),
          (_) => _tick(),
    );
  }

  void _tick() {
    if (!mounted || !_controller.hasClients) return;

    final position = _controller.position;
    if (position.maxScrollExtent <= 4) return;

    if (_pauseAtBottom) return;

    final next = position.pixels + (0.55 * widget.speedMultiplier);
    if (next >= position.maxScrollExtent - 1) {
      _pauseAtBottom = true;
      Future<void>.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpTo(0);
        _pauseAtBottom = false;
      });
      return;
    }

    _controller.jumpTo(next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _manualScroll(double delta) {
    if (!mounted || !_controller.hasClients) return;

    final position = _controller.position;
    final target = (position.pixels + delta)
        .clamp(0.0, position.maxScrollExtent);

    _controller.jumpTo(target);
    _pauseAtBottom = false;

    _resumeTimer?.cancel();
    _resumeTimer = Timer(
      const Duration(seconds: 3),
          () {
        if (!mounted) return;
        _pauseAtBottom = false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: const TextStyle(
            color: Color(0xFF5F6670),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(13),
      ),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _manualScroll(event.scrollDelta.dy);
          }
        },
        child: ListView.separated(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 18),
          itemCount: widget.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final order = widget.orders[index];
            return widget.itemBuilder(order);
          },
        ),
      ),
    );
  }
}

enum _ArchiveRange {
  today,
  week,
  month,
  custom,
}

enum _DeadlineLevel {
  safe,
  watch,
  tomorrow,
  late,
  completed,
}

enum _HighlightType {
  none,
  newOrder,
  inProgress,
  completed,
  receipt,
  deadline,
  attendance,
}

class _VoiceEvent {
  const _VoiceEvent({
    required this.key,
    required this.priority,
    required this.text,
    required this.orderId,
    required this.type,
  });

  final String key;
  final int priority;
  final String text;
  final String orderId;
  final _HighlightType type;
}
