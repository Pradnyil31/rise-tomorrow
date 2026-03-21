import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Top-level background message handler (must be top-level, not a method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  // Firebase is already initialised when this is called by the system.
  // Show a local notification so the user sees it even in background.
  await NotificationService().showTimerComplete(
    title: message.notification?.title ?? 'Rise Tomorrow',
    body: message.notification?.body ?? '',
  );
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Call once during app startup (after Firebase.initializeApp).
  Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS / Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Get and store FCM token
    await _refreshAndSaveToken();

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('[FCM] Token refreshed');
      await _saveTokenToFirestore(token);
    });

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from a notification tap (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // App opened from a terminated state via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleMessageOpenedApp(initial);
    }
  }

  Future<void> _refreshAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token: $token');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('[FCM] Could not get token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    final notification = message.notification;
    if (notification != null) {
      await NotificationService().showTimerComplete(
        title: notification.title ?? 'Rise Tomorrow',
        body: notification.body ?? '',
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Opened from notification: ${message.data}');
    // Navigation can be added here when a router ref is available.
  }

  /// Call this after sign-in to make sure the token is associated with
  /// the newly authenticated user.
  Future<void> refreshTokenForCurrentUser() => _refreshAndSaveToken();
}
