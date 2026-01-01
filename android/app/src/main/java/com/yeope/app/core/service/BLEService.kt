package com.yeope.app.core.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.yeope.app.MainActivity
import com.yeope.app.R
import com.yeope.app.core.ble.BLEAdvertiser
import com.yeope.app.core.ble.BLEGattServer
import com.yeope.app.core.ble.BLEScanner
import com.yeope.app.core.token.TokenManager
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class BLEService : Service() {

    @Inject lateinit var bleScanner: BLEScanner
    @Inject lateinit var bleAdvertiser: BLEAdvertiser
    @Inject lateinit var bleGattServer: BLEGattServer
    @Inject lateinit var tokenManager: TokenManager

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
    }

    private fun startForegroundService() {
        createNotificationChannel()

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("YEO.PE Radar Active")
            .setContentText("Scanning for nearby people...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Connectivity Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        
        when (action) {
            ACTION_START_SCAN -> {
                Log.d("BLEService", "Received Start Command")
                bleScanner.startScanning()
                
                val uid = tokenManager.getUserId()
                if (uid != null) {
                    bleAdvertiser.startAdvertising(uid)
                    bleGattServer.startServer(uid) // Start GATT Server for iOS compatibility
                } else {
                    Log.w("BLEService", "No User ID found, skipping advertising")
                }
            }
            ACTION_STOP_SCAN -> {
                Log.d("BLEService", "Received Stop Command")
                bleScanner.stopScanning()
                bleAdvertiser.stopAdvertising()
                bleGattServer.stopServer()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        
        return START_STICKY
    }
    
    companion object {
        const val CHANNEL_ID = "BLEServiceChannel"
        const val NOTIFICATION_ID = 1
        
        const val ACTION_START_SCAN = "ACTION_START_SCAN"
        const val ACTION_STOP_SCAN = "ACTION_STOP_SCAN"
    }
}
