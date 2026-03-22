package com.risetomorrow.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.util.Calendar

object AppBlockerScheduleManager {
    const val PREFS_NAME = "AppBlockerPrefs"
    const val KEY_SCHEDULES = "schedules_json"
    const val KEY_PACKAGES = "blocked_packages"

    const val ACTION_START_SCHEDULE = "com.risetomorrow.app.ACTION_START_SCHEDULE"
    const val ACTION_STOP_SCHEDULE = "com.risetomorrow.app.ACTION_STOP_SCHEDULE"
    const val ACTION_WARN_SCHEDULE = "com.risetomorrow.app.ACTION_WARN_SCHEDULE"

    const val WARN_MINUTES = 5

    fun getDeviceContext(context: Context): Context {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.createDeviceProtectedStorageContext()
        } else {
            context
        }
    }

    fun updateSchedules(context: Context, schedulesJson: String, packages: List<String>) {
        val prefs = getDeviceContext(context).getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_SCHEDULES, schedulesJson)
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .apply()
        reschedule(context)
    }

    fun getBlockedPackages(context: Context): List<String> {
        val prefs = getDeviceContext(context).getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_PACKAGES, emptySet())?.toList() ?: emptyList()
    }

    fun reschedule(context: Context) {
        val prefs = getDeviceContext(context).getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonString = prefs.getString(KEY_SCHEDULES, "[]") ?: "[]"
        
        try {
            val arr = JSONArray(jsonString)
            var nextStartMs = Long.MAX_VALUE
            var nextStopMs = Long.MAX_VALUE
            var nextWarnMs = Long.MAX_VALUE
            var isCurrentlyInBlock = false

            val nowMs = System.currentTimeMillis()
            val nowCal = Calendar.getInstance()
            // Convert Android Calendar.DAY_OF_WEEK to Flutter format (1=Mon, 7=Sun)
            val todayDay = if (nowCal.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) 7 else nowCal.get(Calendar.DAY_OF_WEEK) - 1

            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (!obj.getBoolean("isEnabled")) continue
                
                val startParts = obj.getString("startTime").split(":")
                val endParts = obj.getString("endTime").split(":")
                val daysArr = obj.getJSONArray("days")
                val daysList = mutableListOf<Int>()
                for (j in 0 until daysArr.length()) daysList.add(daysArr.getInt(j))

                // Check if currently inside this block
                if (daysList.contains(todayDay)) {
                    val calStart = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, startParts[0].toInt())
                        set(Calendar.MINUTE, startParts[1].toInt())
                        set(Calendar.SECOND, 0)
                    }
                    val calEnd = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, endParts[0].toInt())
                        set(Calendar.MINUTE, endParts[1].toInt())
                        set(Calendar.SECOND, 0)
                    }
                    if (nowMs >= calStart.timeInMillis && nowMs < calEnd.timeInMillis) {
                        isCurrentlyInBlock = true
                    }
                }

                // Find next occurrences globally
                val startMs = getNextOccurrence(startParts[0].toInt(), startParts[1].toInt(), daysList)
                val stopMs = getNextOccurrence(endParts[0].toInt(), endParts[1].toInt(), daysList)
                
                if (startMs in (nowMs + 1)..<nextStartMs) nextStartMs = startMs
                if (stopMs in (nowMs + 1)..<nextStopMs) nextStopMs = stopMs
                
                val warnMs = startMs - (WARN_MINUTES * 60 * 1000)
                if (warnMs in (nowMs + 1)..<nextWarnMs) nextWarnMs = warnMs
            }

            // Auto-start via immediate alarm if inside a block
            if (isCurrentlyInBlock) {
                setAlarm(context, ACTION_START_SCHEDULE, nowMs + 1000, 100)
            } else {
                setAlarm(context, ACTION_START_SCHEDULE, if (nextStartMs == Long.MAX_VALUE) 0 else nextStartMs, 100)
            }
            
            setAlarm(context, ACTION_STOP_SCHEDULE, if (nextStopMs == Long.MAX_VALUE) 0 else nextStopMs, 101)
            setAlarm(context, ACTION_WARN_SCHEDULE, if (nextWarnMs == Long.MAX_VALUE) 0 else nextWarnMs, 102)

        } catch (e: Exception) {
            Log.e("AppBlocker", "Error parsing schedules", e)
        }
    }

    private fun getNextOccurrence(hour: Int, minute: Int, daysOfWeek: List<Int>): Long {
        val now = Calendar.getInstance()
        var bestMs = Long.MAX_VALUE

        for (d in daysOfWeek) {
            val calD = if (d == 7) Calendar.SUNDAY else d + 1
            
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, hour)
            cal.set(Calendar.MINUTE, minute)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            
            while (cal.get(Calendar.DAY_OF_WEEK) != calD || cal.timeInMillis <= now.timeInMillis) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            if (cal.timeInMillis < bestMs) bestMs = cal.timeInMillis
        }
        return bestMs
    }

    private fun setAlarm(context: Context, action: String, timeMs: Long, requestCode: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AppBlockerAlarmReceiver::class.java).apply { this.action = action }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (timeMs == 0L) {
            am.cancel(pi)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, timeMs, pi)
            }
        } catch (e: SecurityException) {
            Log.e("AppBlocker", "Exact alarm permission missing", e)
        }
    }

    fun showWarningNotification(context: Context) {
        val channelId = "app_blocker_warn_channel"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Schedule Warnings", NotificationManager.IMPORTANCE_HIGH)
            nm.createNotificationChannel(channel)
        }
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Focus Schedule Starting Soon")
            .setContentText("App Blocker will activate in $WARN_MINUTES minutes.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        nm.notify(8888, builder.build())
    }
}
