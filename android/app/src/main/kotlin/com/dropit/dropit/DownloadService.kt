package com.dropit.dropit

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadService : Service() {
    companion object {
        const val CHANNEL_ID = "dropit_downloads"
        const val NOTIF_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DropIt")
            .setContentText("Download in progress...")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .build()
        startForeground(NOTIF_ID, notif)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "DropIt Downloads",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
