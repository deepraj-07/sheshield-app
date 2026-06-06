package com.sheshield.app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * LocationUpdateService — foreground service for background location tracking.
 * Used during Journey Mode to monitor route deviation.
 * Currently a stub — extend when journey mode background tracking is implemented.
 */
class LocationUpdateService : Service() {

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LocationUpdateService created")
        startForegroundWithNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "LocationUpdateService started")
        // TODO: Start location updates for journey mode tracking
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "LocationUpdateService destroyed")
        // TODO: Stop location updates
    }

    private fun startForegroundWithNotification() {
        val channelId = "sheshield_location_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "SheShield Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used during Journey Mode for route monitoring"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("SheShield")
            .setContentText("Journey mode active — monitoring your route")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val TAG = "SheShield:LocationSvc"
        private const val NOTIFICATION_ID = 1001
    }
}
