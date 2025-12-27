package com.example.medicine_reminder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.intent.action.BOOT_COMPLETED" ||
            intent.action == "android.intent.action.MY_PACKAGE_REPLACED") {

            // Create a notification channel if needed
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "boot_channel",
                    "Device Boot",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications for device boot events"
                }
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                notificationManager?.createNotificationChannel(channel)
            }

            // Create an intent to open the app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            // Build and show notification to prompt user to open app for reminder recovery
            val notification = NotificationCompat.Builder(context, "boot_channel")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Medicine Reminders")
                .setContentText("Device restarted. Tap to restore your medicine reminders.")
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build()

            val notificationManager = context.getSystemService(NotificationManager::class.java)
            notificationManager?.notify(9999, notification)
        }
    }
}