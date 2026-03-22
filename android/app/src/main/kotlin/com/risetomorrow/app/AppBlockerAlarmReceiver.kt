package com.risetomorrow.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AppBlockerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AppBlocker", "Alarm received: ${intent.action}")
        when (intent.action) {
            AppBlockerScheduleManager.ACTION_START_SCHEDULE -> {
                // Feature 5: Close running apps (Go to Home)
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(homeIntent)
                
                // Start blocking
                val packages = AppBlockerScheduleManager.getBlockedPackages(context)
                val serviceIntent = Intent(context, AppBlockerForegroundService::class.java).apply {
                    action = AppBlockerForegroundService.ACTION_START
                    putStringArrayListExtra(AppBlockerForegroundService.EXTRA_PACKAGES, ArrayList(packages))
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
            AppBlockerScheduleManager.ACTION_STOP_SCHEDULE -> {
                val serviceIntent = Intent(context, AppBlockerForegroundService::class.java).apply {
                    action = AppBlockerForegroundService.ACTION_STOP
                }
                context.startService(serviceIntent)
            }
            AppBlockerScheduleManager.ACTION_WARN_SCHEDULE -> {
                // Feature 8: Send warning notification
                AppBlockerScheduleManager.showWarningNotification(context)
            }
        }
        
        // Reschedule next occurrences
        AppBlockerScheduleManager.reschedule(context)
    }
}
