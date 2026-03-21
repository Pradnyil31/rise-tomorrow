
# FocusFlow - AI Implementation Guide
## Cross-Platform Flutter Productivity App

---

## 1. PROJECT OVERVIEW

**App Name:** FocusFlow  
**Platform:** Flutter (iOS & Android)  
**Backend:** Firebase  
**Target Users:** Students, Professionals, Remote Workers, General Users  

**Core Value Proposition:**  
All-in-one focus enhancement combining time tracking, app blocking, task management, and analytics.

---

## 2. SYSTEM ARCHITECTURE

### 2.1 Tech Stack
```
Frontend: Flutter (Dart)
Backend: Firebase
  - Auth: Firebase Authentication
  - Database: Cloud Firestore
  - Notifications: Firebase Cloud Messaging
  - Analytics: Firebase Analytics
  - Crash Reporting: Crashlytics
State Management: Provider/Riverpod (recommended)
Local Storage: Hive/SharedPreferences + SQLite
Permissions: permission_handler package
App Blocking: usage_stats (Android), screen_time (iOS)
```

### 2.2 Database Schema (Firestore)

```dart
// Collection: users
{
  uid: string,
  email: string,
  displayName: string,
  userType: enum['student', 'professional', 'remote_worker', 'freelancer', 'creative', 'developer', 'general'],
  createdAt: timestamp,
  settings: {
    darkMode: bool,
    notifications: bool,
    biometricAuth: bool,
    defaultFocusDuration: int // minutes
  },
  subscription: enum['free', 'premium']
}

// Collection: tasks
{
  taskId: string,
  userId: string (ref),
  title: string (max 100 chars),
  description: string (optional),
  dueDate: timestamp (optional),
  priority: enum['low', 'medium', 'high'],
  status: enum['pending', 'completed', 'archived'],
  tags: array<string>,
  subtasks: array<{
    title: string,
    completed: bool
  }>,
  createdAt: timestamp,
  completedAt: timestamp (optional)
}

// Collection: focusSessions
{
  sessionId: string,
  userId: string (ref),
  type: enum['deep_work', 'meeting', 'study', 'creative', 'planning', 'custom'],
  sessionName: string,
  startTime: timestamp,
  endTime: timestamp,
  duration: int, // planned minutes
  actualDuration: int, // actual minutes completed
  completed: bool,
  autoStart: bool,
  notes: string,
  blockedApps: array<string>, // package names
  createdAt: timestamp
}

// Collection: appUsage
{
  userId: string (ref),
  date: date,
  appPackage: string,
  appName: string,
  category: enum['social', 'entertainment', 'games', 'productivity', 'communication', 'other'],
  usageTime: int, // minutes
  openCount: int,
  blockedAttempts: int
}

// Collection: blockedApps
{
  userId: string (ref),
  appPackage: string,
  appName: string,
  category: string,
  blockSchedules: array<{
    days: array<int>, // 0=Monday, 6=Sunday
    startTime: string, // "HH:mm"
    endTime: string,
    isActive: bool
  }>,
  strictMode: bool, // prevents disabling during active session
  quickBlockMinutes: int (optional) // for one-time blocks
}

// Collection: notifications
{
  notificationId: string,
  userId: string (ref),
  type: enum['task_reminder', 'focus_complete', 'break_start', 'overdue', 'daily_summary', 'motivational'],
  title: string,
  body: string,
  scheduledTime: timestamp,
  sent: bool,
  data: map // payload for navigation
}
```

---

## 3. FEATURE IMPLEMENTATION GUIDE

### 3.1 ONBOARDING FLOW
**Files:** `lib/screens/onboarding/`

**Implementation Steps:**
1. **Welcome Screen** - Value proposition with animated illustrations
2. **User Type Selection** - Grid of 7 user types with icons
   - Store selection in `user.userType`
   - Pre-populate default categories based on type
3. **Goal Setting** (Optional) - Multi-select focus goals
4. **Permission Handler** - Request permissions with context:
   ```dart
   // Android
   await Permission.usageStats.request();
   await Permission.systemAlertWindow.request(); // Display over apps
   await Permission.accessibility.request(); // Detect app launches

   // iOS
   await Permission.appTrackingTransparency.request();
   ```
5. **Quick Tutorial** - 3-page interactive guide using `flutter_onboarding_slider`
6. **First Task** (Optional) - Inline task creation

**User Type Configuration:**
```dart
Map<String, dynamic> userTypeConfig = {
  'student': {
    'defaultCategories': ['Study', 'Assignments', 'Exams', 'Reading'],
    'suggestedFocusDuration': 45,
    'blockingSuggestions': ['Instagram', 'TikTok', 'Games'],
    'dashboardPriority': ['tasks', 'timer', 'analytics']
  },
  'professional': {
    'defaultCategories': ['Meetings', 'Projects', 'Email', 'Planning'],
    'suggestedFocusDuration': 60,
    'blockingSuggestions': ['Facebook', 'Twitter', 'News'],
    'dashboardPriority': ['calendar', 'tasks', 'focus_sessions']
  },
  // ... similar for other types
};
```

---

### 3.2 TIME MANAGEMENT MODULE
**Files:** `lib/screens/timer/`, `lib/services/timer_service.dart`

#### 3.2.1 Stopwatch
**UI Components:**
- Large digital display (HH:MM:SS.ms)
- Start/Pause/Reset buttons (circular FABs)
- Lap list (ListView with timestamps)

**Logic:**
```dart
class StopwatchService {
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  List<Lap> laps = [];

  void start() {
    _stopwatch.start();
    _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
      notifyListeners();
    });
  }

  void recordLap() {
    laps.add(Lap(
      number: laps.length + 1,
      timestamp: DateTime.now(),
      elapsed: _stopwatch.elapsed
    ));
  }

  // Background operation via Isolate or foreground service
}
```

#### 3.2.2 Timer
**UI Components:**
- Circular progress indicator (custom painter)
- Preset chips: 5, 15, 25, 45, 60 minutes
- Custom duration picker
- Color transition: Green (start) → Yellow (middle) → Red (end)

**Logic:**
```dart
class CountdownTimer {
  int duration; // seconds
  Timer? _timer;

  void start() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (duration > 0) {
        duration--;
        notifyListeners();
      } else {
        _onComplete();
      }
    });
  }

  void _onComplete() {
    // Play sound + vibration
    AudioService.playAlarm();
    HapticService.heavyImpact();
    NotificationService.showTimerCompleteNotification();
  }
}
```

#### 3.2.3 Pomodoro
**UI Components:**
- Session counter (4 circles)
- Mode indicator (Work/Break/Long Break)
- Settings gear for customization

**Logic:**
```dart
class PomodoroService {
  int workDuration = 25; // configurable
  int shortBreak = 5;
  int longBreak = 15;
  int sessionsBeforeLongBreak = 4;
  int completedSessions = 0;
  bool isWorkPhase = true;

  void completeSession() {
    completedSessions++;
    if (completedSessions % sessionsBeforeLongBreak == 0) {
      startLongBreak();
    } else {
      startShortBreak();
    }
    FirestoreService.savePomodoroSession(this);
  }
}
```

#### 3.2.4 Multiple Focus Sessions
**UI Components:**
- Daily timeline view (vertical scroll)
- Session cards with color coding by type
- Conflict warning banner
- "Add Session" FAB

**Data Structure:**
```dart
class FocusSession {
  String id;
  String name;
  DateTime startTime;
  DateTime endTime;
  SessionType type;
  bool autoStart;
  bool isCompleted;

  bool conflictsWith(FocusSession other) {
    return startTime.isBefore(other.endTime) && 
           endTime.isAfter(other.startTime);
  }
}
```

**Smart Suggestions Algorithm:**
```dart
List<FocusSession> suggestOptimalSessions() {
  // Analyze past 30 days of focus sessions
  // Find peak productivity hours
  // Suggest 2-4 sessions based on user type
  // Avoid scheduling during existing calendar events
}
```

---

### 3.3 APP BLOCKING MODULE
**Files:** `lib/services/app_blocking_service.dart`, `lib/screens/app_blocker/`

**Platform Implementation:**

**Android:**
```dart
// Uses UsageStatsManager + AccessibilityService + Overlay permission
class AndroidAppBlocker {
  static const platform = MethodChannel('com.focusflow/app_blocker');

  Future<void> startBlocking(List<String> packageNames) async {
    await platform.invokeMethod('startBlocking', {
      'packages': packageNames,
      'strictMode': strictMode
    });
  }

  // AccessibilityService detects app launches
  // Shows blocking overlay via SYSTEM_ALERT_WINDOW
}
```

**iOS:**
```dart
// Uses ScreenTime API (FamilyControls + ManagedSettings)
import 'package:screen_time/screen_time.dart';

class IOSAppBlocker {
  Future<void> blockApps(List<String> bundleIds) async {
    await ScreenTime.blockApplications(bundleIds);
  }
}
```

**UI Components:**
- App list with icons (GridView)
- Category filter chips
- Search bar with debounce
- Batch selection mode
- Schedule picker (Days + TimeRange)
- Strict mode toggle

**Blocking Modes:**
1. **Focus Session**: Block during active timer/pomodoro
2. **Scheduled**: Recurring blocks (e.g., 9-5 weekdays)
3. **Quick Block**: One-time 15/30/60 min blocks
4. **Strict Mode**: Require password to disable (store in Keychain)

---

### 3.4 TASK MANAGEMENT MODULE
**Files:** `lib/screens/tasks/`, `lib/models/task.dart`

**UI Components:**
- Task list with dismissible tiles
- Priority indicators (color + icon)
- Category chips
- Subtask expansion
- Drag-to-reorder (ReorderableListView)
- FAB with expand animation (Add Task, Add Category, Voice Input)

**Views:**
1. **Daily View**: Group by time of day (Morning/Afternoon/Evening)
2. **Weekly View**: Calendar grid with task dots
3. **All Tasks**: Sortable/filterable list
4. **Completed**: Archive with undo option

**Task Model:**
```dart
@freezed
class Task with _$Task {
  factory Task({
    required String id,
    required String title,
    String? description,
    DateTime? dueDate,
    @Default(Priority.medium) Priority priority,
    @Default(TaskStatus.pending) TaskStatus status,
    @Default([]) List<String> tags,
    @Default([]) List<Subtask> subtasks,
  }) = _Task;
}
```

**Features:**
- Swipe actions: Complete (right), Delete (left)
- Pull-to-refresh
- Empty states with illustrations
- Quick add from notification shade

---

### 3.5 DATA EXPORT MODULE
**Files:** `lib/services/export_service.dart`

**Export Formats:**

**CSV Export:**
```dart
Future<String> exportTasksToCSV(List<Task> tasks) async {
  String csv = 'ID,Title,Description,DueDate,Priority,Status,Tags\n';
  for (var task in tasks) {
    csv += '${task.id},"${task.title}",...\n';
  }
  await Share.shareFiles([filePath], text: 'FocusFlow Tasks Export');
}
```

**PDF Export (using pdf package):**
```dart
Future<void> exportToPDF(List<Task> tasks, ExportType type) async {
  final pdf = pw.Document();

  pdf.addPage(pw.Page(
    build: (context) => pw.Column(
      children: [
        pw.Header(text: 'FocusFlow Report'),
        pw.Table.fromTextArray(
          headers: ['Task', 'Priority', 'Due Date', 'Status'],
          data: tasks.map((t) => [t.title, t.priority.name, ...]).toList(),
        ),
        if (type == ExportType.analytics) ...[
          pw.Chart(...), // Productivity charts
        ]
      ],
    ),
  ));
}
```

**Printable To-Do List:**
- Layout options: Compact, Detailed, Priority Matrix, Time-Blocked, Category View
- Checkboxes: `pw.Checkbox(value: false, name: 'task_${task.id}')`
- QR Code: `pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: 'focusflow://import?date=$date')`
- Notes section at bottom

**Analytics Charts:**
- Use `fl_chart` package
- Screen time bar chart (daily/weekly)
- Focus trend line chart
- Productivity score radial gauge
- Distraction score (calculated from blocked app attempts)

---

### 3.6 NOTIFICATION SYSTEM
**Files:** `lib/services/notification_service.dart`

**Setup (flutter_local_notifications + FCM):**
```dart
class NotificationService {
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    await _local.initialize(settings);
    await _fcm.requestPermission();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  // Schedule local notifications
  Future<void> scheduleTaskReminder(Task task) async {
    await _local.zonedSchedule(
      task.id.hashCode,
      'Task Due Soon',
      task.title,
      tz.TZDateTime.from(task.dueDate!.subtract(Duration(minutes: 15)), tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
```

**Notification Types:**
| Type | Trigger | Action |
|------|---------|--------|
| Task Reminder | 15 min before due | Open task detail |
| Overdue Alert | Daily at 9AM | Show overdue list |
| Focus Complete | Timer ends | Show break/start next |
| Blocked App Attempt | User opens blocked app | Show motivational message |
| Daily Summary | 8PM | Show screen time stats |
| Streak | 3+ days focus | Celebration notification |

---

## 4. UI/UX SPECIFICATIONS

### 4.1 Design System

**Colors:**
```dart
class AppColors {
  static const primary = Color(0xFF6366F1); // Indigo
  static const secondary = Color(0xFFEC4899); // Pink
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Red
  static const background = Color(0xFFF3F4F6); // Gray 100
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1F2937);
}
```

**Typography:**
```dart
class AppTextStyles {
  static const heading1 = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1);
  static const heading2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 16, fontWeight: FontWeight.normal);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey);
}
```

**Animations:**
- Page transitions: `PageTransitionType.fade` (200ms)
- List items: Staggered animation (50ms delay between items)
- Timer: Smooth circular progress (60fps)
- Task completion: Strikethrough + fade + checkmark scale
- Haptic feedback on button presses

### 4.2 Screen Specifications

**Home/Dashboard:**
- AppBar: Greeting + Profile avatar + Streak badge
- Active session card (if running) with live timer
- Today's focus summary (circular progress)
- Quick actions row (Start Focus, Block Apps, Add Task)
- Upcoming tasks (3 items max, "View All" link)
- Daily insight card (tip or stat)

**Timer Screen:**
- TabBar: Stopwatch | Timer | Pomodoro
- Large central timer display
- Control buttons in bottom sheet
- History list below fold

**App Blocker:**
- Segmented control: Active | Scheduled | Quick Block
- App grid with selection state
- "Start Focus Session" CTA (disabled if no apps selected)

**Tasks Screen:**
- Calendar strip at top (horizontal scroll)
- Filter chips: All | High Priority | Today | Overdue
- Floating "Add" button with morphing animation

---

## 5. SECURITY & PERFORMANCE

### 5.1 Security Implementation
```dart
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /tasks/{taskId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    // ... similar for all collections
  }
}
```

**Local Security:**
- Store credentials in Keychain (iOS) / Keystore (Android)
- AES-256 encryption for sensitive data using `encrypt` package
- Biometric auth via `local_auth` package

### 5.2 Performance Targets
- Cold start: < 2 seconds (use `flutter_native_splash` + lazy loading)
- First meaningful paint: < 1 second
- Animation jank: 0 frames (target 60fps)
- List scroll: 120fps with `ListView.builder`
- Image loading: Cached with `cached_network_image`

**Optimization Strategies:**
- Pagination for task lists (20 items per page)
- Debounce search queries (300ms)
- Compress images before upload
- Use `const` constructors everywhere possible
- Isolate heavy computations (JSON parsing, PDF generation)

---

## 6. TESTING CHECKLIST

### 6.1 Unit Tests
- [ ] Timer logic (start, pause, reset, complete)
- [ ] Task model (serialization, validation)
- [ ] App blocking service (permission handling)
- [ ] Export service (CSV/PDF generation)
- [ ] Notification scheduling

### 6.2 Widget Tests
- [ ] Onboarding flow navigation
- [ ] Task list interactions (complete, delete, reorder)
- [ ] Timer UI state changes
- [ ] Form validations

### 6.3 Integration Tests
- [ ] End-to-end focus session (start timer → block apps → complete)
- [ ] Data export and share
- [ ] Background timer operation
- [ ] Firebase sync (offline → online)

### 6.4 Platform-Specific Tests
**Android:**
- [ ] Accessibility service detection
- [ ] Overlay permission handling
- [ ] Background execution (doze mode)
- [ ] Different manufacturer behaviors (Samsung, Xiaomi, etc.)

**iOS:**
- [ ] ScreenTime API permissions
- [ ] Background app refresh
- [ ] Notification permissions
- [ ] App Store compliance (blocking restrictions)

---

## 7. DEPENDENCIES (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_messaging: ^14.7.0
  firebase_analytics: ^10.8.0
  firebase_crashlytics: ^3.4.0

  # State Management
  flutter_riverpod: ^2.4.0

  # UI Components
  flutter_svg: ^2.0.0
  fl_chart: ^0.66.0
  shimmer: ^3.0.0
  flutter_slidable: ^3.0.0
  flutter_staggered_animations: ^1.1.0

  # Time & Scheduling
  intl: ^0.19.0
  flutter_local_notifications: ^16.3.0
  timezone: ^0.9.0
  workmanager: ^0.5.0

  # Permissions & Platform
  permission_handler: ^11.2.0
  device_info_plus: ^9.1.0
  app_usage: ^2.0.0  # Android usage stats
  screen_time: ^0.1.0  # iOS ScreenTime

  # Data & Export
  csv: ^5.1.0
  pdf: ^3.10.0
  printing: ^5.11.0
  share_plus: ^7.2.0
  path_provider: ^2.1.0
  hive: ^2.2.0
  hive_flutter: ^1.1.0

  # Security
  encrypt: ^5.0.0
  local_auth: ^2.2.0
  flutter_secure_storage: ^9.0.0

  # Audio & Haptics
  audioplayers: ^5.2.0
  vibration: ^1.8.0

  # Utils
  uuid: ^4.3.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  flutter_launcher_icons: ^0.13.0
```

---

## 8. IMPLEMENTATION ROADMAP

### Phase 1: Core (Weeks 1-3)
- [ ] Project setup + Firebase configuration
- [ ] Authentication (Email + Social)
- [ ] Onboarding flow
- [ ] Basic Task CRUD
- [ ] Simple Timer (no background)

### Phase 2: Focus Features (Weeks 4-6)
- [ ] Pomodoro implementation
- [ ] Stopwatch with laps
- [ ] Background timer execution
- [ ] Multiple focus sessions
- [ ] Basic notifications

### Phase 3: App Blocking (Weeks 7-9)
- [ ] Android app blocking (UsageStats + Accessibility)
- [ ] iOS ScreenTime integration
- [ ] Scheduling system
- [ ] Strict mode

### Phase 4: Analytics & Export (Weeks 10-11)
- [ ] Screen time tracking
- [ ] Charts and visualizations
- [ ] CSV/JSON/PDF export
- [ ] Printable to-do lists

### Phase 5: Polish (Weeks 12-13)
- [ ] Advanced notifications
- [ ] UI animations
- [ ] Dark mode
- [ ] Accessibility (WCAG 2.1)
- [ ] Performance optimization
- [ ] Beta testing

---

## 9. CRITICAL IMPLEMENTATION NOTES

### App Blocking - Android Challenges:
1. **UsageStats permission** requires special permission in manifest + user manual enable
2. **AccessibilityService** must handle app launch detection without lag
3. **Battery optimization** - Add to whitelist programmatically
4. **Overlay permission** - Request "Display over other apps" for blocking UI

### iOS Limitations:
1. **App blocking** requires ScreenTime API (FamilyControls) - limited to supervised devices or MDM in production
2. **Background execution** - Use background fetch for timer updates
3. **Alternative**: Use local notifications + app lifecycle tracking instead of true blocking

### Firebase Optimization:
- Use `withConverter` for type-safe collections
- Implement offline persistence: `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`
- Batch writes for bulk operations
- Index composite queries in Firebase Console

### State Management Pattern:
```dart
// Recommended: Riverpod with AsyncValue
@riverpod
class TasksNotifier extends _$TasksNotifier {
  @override
  Future<List<Task>> build() async {
    return await _fetchTasks();
  }

  Future<void> addTask(Task task) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.addTask(task);
      return [...state.value!, task];
    });
  }
}
```

---

## 10. FILE STRUCTURE

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── routes.dart
│   ├── theme.dart
│   └── constants.dart
├── models/
│   ├── task.dart
│   ├── focus_session.dart
│   ├── app_usage.dart
│   └── user_profile.dart
├── providers/
│   ├── auth_provider.dart
│   ├── tasks_provider.dart
│   ├── timer_provider.dart
│   └── analytics_provider.dart
├── screens/
│   ├── onboarding/
│   ├── auth/
│   ├── home/
│   ├── timer/
│   ├── tasks/
│   ├── app_blocker/
│   ├── analytics/
│   └── settings/
├── services/
│   ├── firebase_service.dart
│   ├── notification_service.dart
│   ├── app_blocking_service.dart
│   ├── export_service.dart
│   └── audio_service.dart
├── widgets/
│   ├── common/
│   ├── timer/
│   └── tasks/
└── utils/
    ├── extensions.dart
    ├── helpers.dart
    └── validators.dart
```

---

**End of AI Implementation Guide**
