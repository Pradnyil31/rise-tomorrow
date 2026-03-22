package com.risetomorrow.app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AppBlockerPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.risetomorrow/app_blocker")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasUsageStatsPermission" -> result.success(hasUsageStatsPermission())
            "requestUsageStatsPermission" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(context))
            "requestOverlayPermission" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "startBlocking" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                val strictMode = call.argument<Boolean>("strictMode") ?: false
                startBlockingService(packages, strictMode)
                result.success(null)
            }
            "stopBlocking" -> {
                stopBlockingService()
                result.success(null)
            }
            "updateSchedules" -> {
                val schedulesJson = call.argument<String>("schedulesJson") ?: "[]"
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                AppBlockerScheduleManager.updateSchedules(context, schedulesJson, packages)
                result.success(null)
            }
            "isBlockingActive" -> result.success(isServiceRunning())
            "getInstalledApps" -> {
                Thread {
                    try {
                        val apps = getInstalledApps()
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(apps)
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("APPS_ERROR", e.message, null)
                        }
                    }
                }.start()
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("package") ?: ""
                Thread {
                    try {
                        val pm = context.packageManager
                        val info = pm.getApplicationInfo(packageName, 0)
                        val icon = pm.getApplicationIcon(info)
                        val bytes = getIconByteArray(icon)
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(bytes)
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(null)
                        }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    private fun isServiceRunning(): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE)
                as android.app.ActivityManager
        return manager.getRunningServices(Int.MAX_VALUE).any {
            it.service.className == AppBlockerForegroundService::class.java.name
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun startBlockingService(packages: List<String>, strictMode: Boolean) {
        val intent = Intent(context, AppBlockerForegroundService::class.java).apply {
            action = AppBlockerForegroundService.ACTION_START
            putStringArrayListExtra(AppBlockerForegroundService.EXTRA_PACKAGES, ArrayList(packages))
            putExtra(AppBlockerForegroundService.EXTRA_STRICT, strictMode)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopBlockingService() {
        val intent = Intent(context, AppBlockerForegroundService::class.java).apply {
            action = AppBlockerForegroundService.ACTION_STOP
        }
        context.startService(intent)
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val flags = PackageManager.GET_META_DATA
        val apps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(flags)
        }
        return apps
            .filter { pm.getLaunchIntentForPackage(it.packageName) != null } // apps with launcher icon
            .filter { it.packageName != context.packageName } // exclude self
            .mapNotNull { info ->
                try {
                    val label = pm.getApplicationLabel(info).toString()
                    mapOf(
                        "name" to label,
                        "package" to info.packageName,
                        "category" to categoryFor(info.category)
                    )
                } catch (e: Exception) { null }
            }
            .sortedBy { it["name"].toString() }
    }

    private fun getIconByteArray(drawable: android.graphics.drawable.Drawable): ByteArray {
        val bitmap = if (drawable is android.graphics.drawable.BitmapDrawable) {
            drawable.bitmap
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && drawable is android.graphics.drawable.AdaptiveIconDrawable) {
            val bmp = android.graphics.Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
            val bmp = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    private fun categoryFor(category: Int): String = when (category) {
        ApplicationInfo.CATEGORY_SOCIAL -> "social"
        ApplicationInfo.CATEGORY_VIDEO -> "entertainment"
        ApplicationInfo.CATEGORY_AUDIO -> "entertainment"
        ApplicationInfo.CATEGORY_GAME -> "games"
        ApplicationInfo.CATEGORY_NEWS -> "news"
        ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
        else -> "other"
    }
}
