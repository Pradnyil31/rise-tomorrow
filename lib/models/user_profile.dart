// User-facing types
enum UserType {
  student,
  professional,
  remoteWorker,
  freelancer,
  creative,
  developer,
  general,
}

extension UserTypeX on UserType {
  String get key {
    switch (this) {
      case UserType.remoteWorker:
        return 'remote_worker';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case UserType.remoteWorker:
        return 'Remote Worker';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  String get emoji {
    switch (this) {
      case UserType.student:
        return '🎓';
      case UserType.professional:
        return '💼';
      case UserType.remoteWorker:
        return '🏠';
      case UserType.freelancer:
        return '🚀';
      case UserType.creative:
        return '🎨';
      case UserType.developer:
        return '💻';
      case UserType.general:
        return '✨';
    }
  }
}

class BlockSchedule {
  final String id;
  final String startTime;
  final String endTime;
  final List<int> days;
  final bool isEnabled;

  const BlockSchedule({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.days,
    required this.isEnabled,
  });

  BlockSchedule copyWith({
    String? startTime,
    String? endTime,
    List<int>? days,
    bool? isEnabled,
  }) {
    return BlockSchedule(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      days: days ?? this.days,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
        'endTime': endTime,
        'days': days,
        'isEnabled': isEnabled,
      };

  factory BlockSchedule.fromJson(Map<String, dynamic> json) => BlockSchedule(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: json['startTime'] as String? ?? '09:00',
        endTime: json['endTime'] as String? ?? '17:00',
        days: List<int>.from(json['days'] as List? ?? [1, 2, 3, 4, 5]),
        isEnabled: json['isEnabled'] as bool? ?? false,
      );
}

class UserSettings {
  final bool darkMode;
  final bool notifications;
  final bool biometricAuth;
  final int defaultFocusDuration; // minutes
  final List<BlockSchedule> schedules;

  const UserSettings({
    this.darkMode = false,
    this.notifications = true,
    this.biometricAuth = false,
    this.defaultFocusDuration = 25,
    this.schedules = const [],
  });

  UserSettings copyWith({
    bool? darkMode,
    bool? notifications,
    bool? biometricAuth,
    int? defaultFocusDuration,
    List<BlockSchedule>? schedules,
  }) {
    return UserSettings(
      darkMode: darkMode ?? this.darkMode,
      notifications: notifications ?? this.notifications,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      defaultFocusDuration:
          defaultFocusDuration ?? this.defaultFocusDuration,
      schedules: schedules ?? this.schedules,
    );
  }

  Map<String, dynamic> toJson() => {
        'darkMode': darkMode,
        'notifications': notifications,
        'biometricAuth': biometricAuth,
        'defaultFocusDuration': defaultFocusDuration,
        'schedules': schedules.map((s) => s.toJson()).toList(),
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    List<BlockSchedule> defaultSchedules = [];
    
    // Migration for older clients relying on single schedule params
    if (json.containsKey('isScheduleEnabled') || json.containsKey('scheduleStartTime')) {
      defaultSchedules.add(BlockSchedule(
        id: 'default_1',
        startTime: json['scheduleStartTime'] as String? ?? '09:00',
        endTime: json['scheduleEndTime'] as String? ?? '17:00',
        days: List<int>.from(json['scheduleDays'] as List? ?? [1, 2, 3, 4, 5]),
        isEnabled: json['isScheduleEnabled'] as bool? ?? false,
      ));
    }

    return UserSettings(
      darkMode: json['darkMode'] as bool? ?? false,
      notifications: json['notifications'] as bool? ?? true,
      biometricAuth: json['biometricAuth'] as bool? ?? false,
      defaultFocusDuration: json['defaultFocusDuration'] as int? ?? 25,
      schedules: json.containsKey('schedules')
          ? (json['schedules'] as List).map((s) => BlockSchedule.fromJson(s as Map<String, dynamic>)).toList()
          : defaultSchedules,
    );
  }
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final UserType userType;
  final DateTime createdAt;
  final UserSettings settings;
  final String subscription; // 'free' | 'premium'

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.userType = UserType.general,
    required this.createdAt,
    this.settings = const UserSettings(),
    this.subscription = 'free',
  });

  UserProfile copyWith({
    String? displayName,
    UserType? userType,
    UserSettings? settings,
    String? subscription,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      userType: userType ?? this.userType,
      createdAt: createdAt,
      settings: settings ?? this.settings,
      subscription: subscription ?? this.subscription,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'userType': userType.key,
        'createdAt': createdAt.toIso8601String(),
        'settings': settings.toJson(),
        'subscription': subscription,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final userTypeStr = json['userType'] as String? ?? 'general';
    UserType ut;
    if (userTypeStr == 'remote_worker') {
      ut = UserType.remoteWorker;
    } else {
      ut = UserType.values.firstWhere(
        (e) => e.name == userTypeStr,
        orElse: () => UserType.general,
      );
    }
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      userType: ut,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      settings: UserSettings.fromJson(
          (json['settings'] as Map<String, dynamic>?) ?? {}),
      subscription: json['subscription'] as String? ?? 'free',
    );
  }
}
