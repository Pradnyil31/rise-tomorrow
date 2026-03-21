import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/app_blocking_service.dart';
import 'models/user_profile.dart';
import 'config/constants.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == 'checkSchedule') {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return Future.value(true);

        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists) return Future.value(true);

        final profile = UserProfile.fromJson(doc.data()!);
        final settings = profile.settings;

        final now = DateTime.now();
        final currentDay = now.weekday; // 1=Mon, 7=Sun

        // Check if any enabled schedule covers the current time
        bool shouldBlock = false;
        for (final schedule in settings.schedules) {
          if (!schedule.isEnabled) continue;
          if (!schedule.days.contains(currentDay)) continue;

          final startParts = schedule.startTime.split(':');
          final endParts = schedule.endTime.split(':');
          final startTime = DateTime(now.year, now.month, now.day,
              int.parse(startParts[0]), int.parse(startParts[1]));
          final endTime = DateTime(now.year, now.month, now.day,
              int.parse(endParts[0]), int.parse(endParts[1]));

          if (now.isAfter(startTime) && now.isBefore(endTime)) {
            shouldBlock = true;
            break;
          }
        }

        if (shouldBlock) {
          final blockedAppsSnap = await FirebaseFirestore.instance.collection('blockedApps').where('userId', isEqualTo: user.uid).get();
          final packages = blockedAppsSnap.docs.map((d) => d.data()['appPackage'] as String).toList();
          if (packages.isNotEmpty) {
            await AppBlockingService().startBlocking(packageNames: packages);
          }
        } else {
          await AppBlockingService().stopBlocking();
        }

      }
    } catch (_) {
      // ignore
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ────────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics: catch all Flutter framework errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Crashlytics: catch async errors outside Flutter framework
  // (network errors, isolate-level exceptions, etc.)

  // ── Analytics ───────────────────────────────────────────────────────────────
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // ── Hive ────────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.settingsBox);

  // ── Local Notifications ─────────────────────────────────────────────────────
  final notifService = NotificationService();
  await notifService.init();

  // ── FCM ─────────────────────────────────────────────────────────────────────
  await FcmService().init();

  // ── WorkManager ─────────────────────────────────────────────────────────────
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  await Workmanager().registerPeriodicTask(
    "1",
    "checkSchedule",
    frequency: const Duration(minutes: 15),
  );

  // ── Run app inside Crashlytics async guard ──────────────────────────────────
  await runZonedGuarded(
    () async {
      runApp(
        const ProviderScope(
          child: RiseTomorrowApp(),
        ),
      );
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
