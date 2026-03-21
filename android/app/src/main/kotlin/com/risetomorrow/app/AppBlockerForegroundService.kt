package com.risetomorrow.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AppBlockerForegroundService : Service() {

    companion object {
        const val ACTION_START = "START_BLOCKING"
        const val ACTION_STOP = "STOP_BLOCKING"
        const val EXTRA_PACKAGES = "blocked_packages"
        const val EXTRA_STRICT = "strict_mode"
        const val CHANNEL_ID = "app_blocker_channel"
        const val NOTIFICATION_ID = 7777
        const val POLL_INTERVAL_MS = 500L

        @Volatile var isRunning = false
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private val blockedPackages = mutableSetOf<String>()
    private var strictMode = false
    private var lastForegroundPkg: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val packages = intent.getStringArrayListExtra(EXTRA_PACKAGES) ?: arrayListOf()
                strictMode = intent.getBooleanExtra(EXTRA_STRICT, false)
                blockedPackages.clear()
                blockedPackages.addAll(packages)
                Log.d("AppBlocker", "Blocking: $blockedPackages")

                startForeground(NOTIFICATION_ID, buildNotification())
                isRunning = true
                handler.post(pollRunnable)
            }
            ACTION_STOP -> {
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─── Core Blocking Logic ─────────────────────────────────────────────────

    private fun checkForegroundApp() {
        val pkg = getForegroundPackage() ?: return
        if (pkg == lastForegroundPkg) return
        lastForegroundPkg = pkg

        if (pkg in blockedPackages) {
            Log.d("AppBlocker", "Intercepting: $pkg")
            launchOverlay(pkg)
        }
    }

    private fun getForegroundPackage(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                now - 5_000,
                now
            )
            stats?.filter { it.lastTimeUsed > 0 }
                ?.maxByOrNull { it.lastTimeUsed }
                ?.packageName
        } catch (e: Exception) {
            Log.e("AppBlocker", "UsageStats error: ${e.message}")
            null
        }
    }

    private fun launchOverlay(blockedPackage: String) {
        val intent = Intent(this, BlockOverlayActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(BlockOverlayActivity.EXTRA_BLOCKED_PKG, blockedPackage)
        }
        startActivity(intent)
    }

    // ─── Notification ────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Rise Tomorrow focus mode is active"
                setShowBadge(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, AppBlockerForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openPendingIntent = PendingIntent.getActivity(
            this, 1, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🛡️ Focus Mode Active")
            .setContentText("${blockedPackages.size} app(s) blocked — Stay focused!")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .build()
    }
}
