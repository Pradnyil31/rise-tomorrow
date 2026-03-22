import 'package:flutter/services.dart';
import 'dart:convert';

class AppBlockingService {
  static const _channel = MethodChannel('com.risetomorrow/app_blocker');

  // ─── Permissions ────────────────────────────────────────────────────────────

  Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (_) {}
  }

  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  Future<bool> isBlockingActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBlockingActive');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'package': packageName,
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  // ─── Blocking ────────────────────────────────────────────────────────────────

  Future<void> updateSchedules(List<Map<String, dynamic>> schedulesJson, List<String> packageNames) async {
    try {
      await _channel.invokeMethod('updateSchedules', {
        'schedulesJson': jsonEncode(schedulesJson),
        'packages': packageNames,
      });
    } catch (_) {}
  }

  Future<void> startBlocking({
    required List<String> packageNames,
    bool strictMode = false,
  }) async {
    try {
      await _channel.invokeMethod('startBlocking', {
        'packages': packageNames,
        'strictMode': strictMode,
      });
    } on PlatformException catch (e) {
      throw Exception('Could not start blocking: ${e.message}');
    }
  }

  Future<void> stopBlocking() async {
    try {
      await _channel.invokeMethod('stopBlocking');
    } on PlatformException catch (e) {
      throw Exception('Could not stop blocking: ${e.message}');
    }
  }

  /// Returns actual installed apps from device (falls back to sample list if native unavailable)
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      return (result ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on PlatformException {
      return _sampleApps;
    }
  }

  static const List<Map<String, dynamic>> _sampleApps = [
    {'name': 'Instagram', 'package': 'com.instagram.android', 'category': 'social'},
    {'name': 'TikTok', 'package': 'com.zhiliaoapp.musically', 'category': 'social'},
    {'name': 'Facebook', 'package': 'com.facebook.katana', 'category': 'social'},
    {'name': 'YouTube', 'package': 'com.google.android.youtube', 'category': 'entertainment'},
    {'name': 'Twitter / X', 'package': 'com.twitter.android', 'category': 'social'},
    {'name': 'Reddit', 'package': 'com.reddit.frontpage', 'category': 'social'},
    {'name': 'Snapchat', 'package': 'com.snapchat.android', 'category': 'social'},
    {'name': 'Netflix', 'package': 'com.netflix.mediaclient', 'category': 'entertainment'},
    {'name': 'WhatsApp', 'package': 'com.whatsapp', 'category': 'communication'},
    {'name': 'Telegram', 'package': 'org.telegram.messenger', 'category': 'communication'},
    {'name': 'Discord', 'package': 'com.discord', 'category': 'communication'},
    {'name': 'Spotify', 'package': 'com.spotify.music', 'category': 'entertainment'},
    {'name': 'Candy Crush', 'package': 'com.king.candycrushsaga', 'category': 'games'},
    {'name': 'PUBG Mobile', 'package': 'com.tencent.ig', 'category': 'games'},
    {'name': 'Amazon Shopping', 'package': 'com.amazon.mShop.android.shopping', 'category': 'other'},
  ];
}
