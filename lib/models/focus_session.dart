enum SessionType { deepWork, meeting, study, creative, planning, custom }

extension SessionTypeX on SessionType {
  String get label {
    switch (this) {
      case SessionType.deepWork:
        return 'Deep Work';
      case SessionType.meeting:
        return 'Meeting';
      case SessionType.study:
        return 'Study';
      case SessionType.creative:
        return 'Creative';
      case SessionType.planning:
        return 'Planning';
      case SessionType.custom:
        return 'Custom';
    }
  }

  String get key {
    switch (this) {
      case SessionType.deepWork:
        return 'deep_work';
      default:
        return name;
    }
  }
}

class FocusSession {
  final String id;
  final String userId;
  final SessionType type;
  final String sessionName;
  final DateTime startTime;
  final DateTime endTime;
  final int duration;       // planned minutes
  final int actualDuration; // actual minutes completed
  final bool completed;
  final bool autoStart;
  final String notes;
  final List<String> blockedApps;
  final DateTime createdAt;

  const FocusSession({
    required this.id,
    required this.userId,
    required this.type,
    required this.sessionName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.actualDuration = 0,
    this.completed = false,
    this.autoStart = false,
    this.notes = '',
    this.blockedApps = const [],
    required this.createdAt,
  });

  bool conflictsWith(FocusSession other) {
    return startTime.isBefore(other.endTime) &&
        endTime.isAfter(other.startTime);
  }

  FocusSession copyWith({
    int? actualDuration,
    bool? completed,
    String? notes,
  }) {
    return FocusSession(
      id: id,
      userId: userId,
      type: type,
      sessionName: sessionName,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      actualDuration: actualDuration ?? this.actualDuration,
      completed: completed ?? this.completed,
      autoStart: autoStart,
      notes: notes ?? this.notes,
      blockedApps: blockedApps,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.key,
        'sessionName': sessionName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': duration,
        'actualDuration': actualDuration,
        'completed': completed,
        'autoStart': autoStart,
        'notes': notes,
        'blockedApps': blockedApps,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? 'custom';
    SessionType st;
    if (typeStr == 'deep_work') {
      st = SessionType.deepWork;
    } else {
      st = SessionType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => SessionType.custom,
      );
    }
    return FocusSession(
      id: j['id'] as String,
      userId: j['userId'] as String? ?? '',
      type: st,
      sessionName: j['sessionName'] as String? ?? '',
      startTime: DateTime.parse(j['startTime'] as String),
      endTime: DateTime.parse(j['endTime'] as String),
      duration: j['duration'] as int? ?? 0,
      actualDuration: j['actualDuration'] as int? ?? 0,
      completed: j['completed'] as bool? ?? false,
      autoStart: j['autoStart'] as bool? ?? false,
      notes: j['notes'] as String? ?? '',
      blockedApps: List<String>.from(j['blockedApps'] as List? ?? []),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

class Lap {
  final int number;
  final DateTime timestamp;
  final Duration elapsed;
  final Duration lapTime;

  const Lap({
    required this.number,
    required this.timestamp,
    required this.elapsed,
    required this.lapTime,
  });
}
