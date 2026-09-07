import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.attendanceDate,
    required this.slot,
    required this.name,
    required this.status,
    required this.reason,
    required this.checkedInAt,
    required this.createdAt,
    required this.voiceAnnouncedAt,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      return DateTime.parse(value.toString()).toUtc();
    }

    return AttendanceRecord(
      id: map['id'].toString(),
      attendanceDate: map['attendance_date'].toString(),
      slot: map['slot'] as int?,
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      reason: map['reason']?.toString(),
      checkedInAt: parseDate(map['checked_in_at']),
      createdAt: parseDate(map['created_at']),
      voiceAnnouncedAt: map['voice_announced_at'] == null
          ? null
          : parseDate(map['voice_announced_at']),
    );
  }

  final String id;
  final String attendanceDate;
  final int? slot;
  final String name;
  final String status;
  final String? reason;
  final DateTime checkedInAt;
  final DateTime createdAt;
  final DateTime? voiceAnnouncedAt;

  bool get isPresent => status == 'hadir';
  bool get isAbsent => status == 'tidak_hadir';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'attendance_date': attendanceDate,
      'slot': slot,
      'name': name,
      'status': status,
      'reason': reason,
      'checked_in_at': checkedInAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'voice_announced_at': voiceAnnouncedAt?.toIso8601String(),
    };
  }
}

class AttendanceService {
  AttendanceService._();

  static final AttendanceService instance = AttendanceService._();

  SupabaseClient get _client => Supabase.instance.client;

  RealtimeChannel? _channel;

  /// WIB (UTC+7), independent from the local timezone of the device.
  DateTime get nowWib =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  String get todayWib => _dateKey(nowWib);

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<List<AttendanceRecord>> loadToday() async {
    final rows = await _client
        .from('attendance')
        .select()
        .eq('attendance_date', todayWib)
        .order('checked_in_at', ascending: true);

    return (rows as List<dynamic>)
        .map(
          (row) => AttendanceRecord.fromMap(
        Map<String, dynamic>.from(row as Map),
      ),
    )
        .toList();
  }

  Future<AttendanceRecord> markPresent({
    required int slot,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (slot < 1 || slot > 10) {
      throw ArgumentError('Nomor absen harus 1 sampai 10.');
    }
    if (cleanName.isEmpty) {
      throw ArgumentError('Nama wajib diisi.');
    }

    final row = await _client
        .from('attendance')
        .insert(<String, dynamic>{
      'attendance_date': todayWib,
      'slot': slot,
      'name': cleanName,
      'status': 'hadir',
      'reason': null,
    })
        .select()
        .single();

    return AttendanceRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AttendanceRecord> markAbsent({
    required String name,
    required String reason,
  }) async {
    final cleanName = name.trim();
    final cleanReason = reason.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Nama wajib diisi.');
    }
    if (cleanReason.isEmpty) {
      throw ArgumentError('Alasan wajib diisi.');
    }

    final row = await _client
        .from('attendance')
        .insert(<String, dynamic>{
      'attendance_date': todayWib,
      'slot': null,
      'name': cleanName,
      'status': 'tidak_hadir',
      'reason': cleanReason,
    })
        .select()
        .single();

    return AttendanceRecord.fromMap(Map<String, dynamic>.from(row));
  }

  /// Atomically claims an announcement. If another Monitoring device already
  /// claimed it, this returns false, preventing duplicate Queen announcements.
  Future<bool> claimVoiceAnnouncement(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = await _client
        .from('attendance')
        .update(<String, dynamic>{'voice_announced_at': now})
        .eq('id', id)
        .isFilter('voice_announced_at', null)
        .select('id');

    return (rows as List<dynamic>).isNotEmpty;
  }

  void startRealtime({
    required void Function(AttendanceRecord record) onChanged,
  }) {
    _channel?.unsubscribe();

    _channel = _client.channel(
      'attendance-monitor-${DateTime.now().microsecondsSinceEpoch}',
    );

    _channel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'attendance',
      callback: (payload) {
        final source = payload.eventType == PostgresChangeEvent.delete
            ? payload.oldRecord
            : payload.newRecord;

        if (source.isEmpty) return;
        onChanged(AttendanceRecord.fromMap(
          Map<String, dynamic>.from(source),
        ));
      },
    )
        .subscribe();
  }

  Future<void> stopRealtime() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await channel.unsubscribe();
    }
  }
}
