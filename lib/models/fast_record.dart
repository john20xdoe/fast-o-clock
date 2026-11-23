import 'dart:math';

class FastRecord {
  static final Random _secureRandom = Random.secure();

  final String id;
  final String protocolId;
  final int startTimeMs;
  final int? endTimeMs;
  final int targetDurationMin;
  final String? note;
  final String? mood; // 'great', 'okay', 'challenging', 'bad'
  final int createdAtMs;
  final int updatedAtMs;

  const FastRecord({
    required this.id,
    required this.protocolId,
    required this.startTimeMs,
    this.endTimeMs,
    required this.targetDurationMin,
    this.note,
    this.mood,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  static String generateId() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  bool get isActive => endTimeMs == null;

  DateTime get startTimeLocal =>
      DateTime.fromMillisecondsSinceEpoch(startTimeMs, isUtc: true).toLocal();

  DateTime? get endTimeLocal => endTimeMs != null
      ? DateTime.fromMillisecondsSinceEpoch(endTimeMs!, isUtc: true).toLocal()
      : null;

  int get targetEndTimeMs => startTimeMs + targetDurationMin * 60000;

  DateTime get targetEndTimeLocal =>
      DateTime.fromMillisecondsSinceEpoch(targetEndTimeMs, isUtc: true)
          .toLocal();

  Duration elapsedDuration([DateTime? nowUtc]) {
    final effectiveEndMs =
        endTimeMs ?? (nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final diffMs = effectiveEndMs - startTimeMs;
    return Duration(milliseconds: diffMs > 0 ? diffMs : 0);
  }

  Duration remainingDuration([DateTime? nowUtc]) {
    final targetMs = targetDurationMin * 60000;
    final elapsedMs = elapsedDuration(nowUtc).inMilliseconds;
    final remMs = targetMs - elapsedMs;
    return Duration(milliseconds: remMs > 0 ? remMs : 0);
  }

  Duration overGoalDuration([DateTime? nowUtc]) {
    final targetMs = targetDurationMin * 60000;
    final elapsedMs = elapsedDuration(nowUtc).inMilliseconds;
    final overMs = elapsedMs - targetMs;
    return Duration(milliseconds: overMs > 0 ? overMs : 0);
  }

  double progress([DateTime? nowUtc]) {
    if (targetDurationMin <= 0) return 1.0;
    final ratio =
        elapsedDuration(nowUtc).inMilliseconds / (targetDurationMin * 60000.0);
    return ratio.clamp(0.0, 1.0);
  }

  bool isGoalMetAt([DateTime? nowUtc]) =>
      elapsedDuration(nowUtc).inMilliseconds >= targetDurationMin * 60000;

  bool get isGoalMet =>
      endTimeMs != null &&
      ((endTimeMs! - startTimeMs) >= targetDurationMin * 60000);

  FastRecord copyWith({
    String? id,
    String? protocolId,
    int? startTimeMs,
    int? endTimeMs,
    bool clearEndTime = false,
    int? targetDurationMin,
    String? note,
    bool clearNote = false,
    String? mood,
    bool clearMood = false,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return FastRecord(
      id: id ?? this.id,
      protocolId: protocolId ?? this.protocolId,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: clearEndTime ? null : (endTimeMs ?? this.endTimeMs),
      targetDurationMin: targetDurationMin ?? this.targetDurationMin,
      note: clearNote ? null : (note ?? this.note),
      mood: clearMood ? null : (mood ?? this.mood),
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toSqlMap() => {
        'id': id,
        'protocol_id': protocolId,
        'start_time_ms': startTimeMs,
        'end_time_ms': endTimeMs,
        'target_duration_min': targetDurationMin,
        'note': note,
        'mood': mood,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory FastRecord.fromSqlMap(Map<String, Object?> map) {
    return FastRecord(
      id: map['id'] as String,
      protocolId: map['protocol_id'] as String,
      startTimeMs: (map['start_time_ms'] as num).toInt(),
      endTimeMs: (map['end_time_ms'] as num?)?.toInt(),
      targetDurationMin: (map['target_duration_min'] as num).toInt(),
      note: map['note'] as String?,
      mood: map['mood'] as String?,
      createdAtMs: (map['created_at_ms'] as num).toInt(),
      updatedAtMs: (map['updated_at_ms'] as num).toInt(),
    );
  }

  Map<String, dynamic> toBackupJson() => {
        'id': id,
        'protocolId': protocolId,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'targetDurationMin': targetDurationMin,
        'note': note,
        'mood': mood,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory FastRecord.fromBackupJson(Map<String, dynamic> json) {
    return FastRecord(
      id: json['id'] as String,
      protocolId: json['protocolId'] as String,
      startTimeMs: (json['startTimeMs'] as num).toInt(),
      endTimeMs: (json['endTimeMs'] as num?)?.toInt(),
      targetDurationMin: (json['targetDurationMin'] as num).toInt(),
      note: json['note'] as String?,
      mood: json['mood'] as String?,
      createdAtMs: (json['createdAtMs'] as num).toInt(),
      updatedAtMs: (json['updatedAtMs'] as num).toInt(),
    );
  }
}
