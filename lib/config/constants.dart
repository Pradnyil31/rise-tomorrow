class AppConstants {
  AppConstants._();

  static const appName = 'Rise Tomorrow';
  static const appVersion = '1.0.0';

  // Pomodoro defaults
  static const pomodoroWork = 25;
  static const pomodoroShortBreak = 5;
  static const pomodoroLongBreak = 15;
  static const pomodoroSessionsBeforeLong = 4;

  // Timer presets (minutes)
  static const timerPresets = [5, 15, 25, 45, 60];

  // Hive box names
  static const userBox = 'user_box';
  static const settingsBox = 'settings_box';
  static const tasksBox = 'tasks_box';
  static const sessionsBox = 'sessions_box';

  // Secure storage keys
  static const strictModePasswordKey = 'strict_mode_password';

  // User type configs
  static const Map<String, Map<String, dynamic>> userTypeConfig = {
    'student': {
      'label': 'Student',
      'emoji': '🎓',
      'defaultCategories': ['Study', 'Assignments', 'Exams', 'Reading'],
      'suggestedFocusDuration': 45,
      'blockingSuggestions': ['Instagram', 'TikTok', 'Games'],
    },
    'professional': {
      'label': 'Professional',
      'emoji': '💼',
      'defaultCategories': ['Meetings', 'Projects', 'Email', 'Planning'],
      'suggestedFocusDuration': 60,
      'blockingSuggestions': ['Facebook', 'Twitter', 'News'],
    },
    'remote_worker': {
      'label': 'Remote Worker',
      'emoji': '🏠',
      'defaultCategories': ['Work', 'Calls', 'Documentation', 'Breaks'],
      'suggestedFocusDuration': 50,
      'blockingSuggestions': ['YouTube', 'Reddit', 'Slack (personal)'],
    },
    'freelancer': {
      'label': 'Freelancer',
      'emoji': '🚀',
      'defaultCategories': ['Client Work', 'Invoicing', 'Marketing', 'Admin'],
      'suggestedFocusDuration': 45,
      'blockingSuggestions': ['Social Media', 'Games', 'Streaming'],
    },
    'creative': {
      'label': 'Creative',
      'emoji': '🎨',
      'defaultCategories': ['Design', 'Writing', 'Research', 'Review'],
      'suggestedFocusDuration': 90,
      'blockingSuggestions': ['News', 'Social Media'],
    },
    'developer': {
      'label': 'Developer',
      'emoji': '💻',
      'defaultCategories': ['Coding', 'Code Review', 'Learning', 'Meetings'],
      'suggestedFocusDuration': 60,
      'blockingSuggestions': ['Reddit', 'Twitter', 'YouTube'],
    },
    'general': {
      'label': 'General',
      'emoji': '✨',
      'defaultCategories': ['Personal', 'Work', 'Health', 'Learning'],
      'suggestedFocusDuration': 30,
      'blockingSuggestions': ['Social Media', 'Games'],
    },
  };

  // Notification channels
  static const notifChannelTaskId = 'task_reminders';
  static const notifChannelTimerId = 'timer_alerts';
  static const notifChannelSummaryId = 'daily_summary';

  // MethodChannel
  static const appBlockerChannel = 'com.risetomorrow/app_blocker';
}
