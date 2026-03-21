# Rise Tomorrow
**Build a Better Version of You**

Rise Tomorrow is a premium, AI-powered productivity application designed to seamlessly blend task management, deep focus tracking, and strict native app blocking to help craft the perfect daily workflow. Built on Flutter and tightly integrated with Android-native foreground and background services, Rise Tomorrow offers a comprehensive suite of tools to stay productive.

---

## 🚀 Key Features

* **Advanced Task Management**
  * Organize your day with high-priority flagging, tagging, and multi-step subtasks.
  * Synced instantly across devices using Firebase Firestore.
* **Intelligent Focus Timers**
  * Choose between classic Countdown intervals, continuous Stopwatches, or a fully automated Pomodoro sequence.
  * **Analytics Engine:** Timers automatically log completions to Firebase, computing daily totals, consecutive streaks, and weekly focus trends. 
* **Native App Blocking (Android)**
  * Take back your time by preventing access to distracting installed applications.
  * Powered by a native Kotlin Foreground Service and Device Accessibility/Overlay configurations.
  * **Scheduled Blocking:** Define custom schedules (days and hours) to automatically trigger App Blocking in the background using `WorkManager`, regardless of whether the app is open.
* **Modern UI Architecture**
  * Beautiful dark mode designs with glassmorphic elements and buttery smooth micro-animations.
  * Implemented with cutting-edge state management (`flutter_riverpod`).

---

## 🛠 Tech Stack

* **Frontend:** Flutter (`sdk: ^3.6.0`, Material 3 architecture)
* **Backend:** Firebase (Authentication, Firestore, Cloud Messaging, Analytics, Crashlytics)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Local Storage:** Hive (`hive_flutter`) and Secure Storage
* **Native Android:** Kotlin (Foreground Services, MethodChannels, WorkManager)

---

## ⚙️ Project Setup

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.6.0+)
2. Install [Android Studio](https://developer.android.com/studio) and SDK tools.
3. Have a Firebase project configured with Firestore, Auth, and Analytics rules established. 

### Local Run 

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/rise_tomorrow.git
   cd rise_tomorrow
   ```

2. **Retrieve dependencies:**
   ```bash
   flutter pub get
   ```

3. **Provide Secret Credentials:**
   You must export your personal Firebase configuration file into the Android tier.
   * Drop your `google-services.json` into `android/app/`
   * (If testing on iOS, include your `GoogleService-Info.plist` within Xcode directory config).

4. **Run the App:**
   ```bash
   flutter run
   ```

### 📱 Android Permissions Note
If compiling for Android and testing the **App Blocker**, you must manually grant the following permissions in Settings upon first launch:
- Notification Permissions
- Usage Data Access (`PACKAGE_USAGE_STATS`)
- Display over other apps (`SYSTEM_ALERT_WINDOW`)

---

*Rise Tomorrow - Build a Better Version of You*
