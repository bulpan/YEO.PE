package com.yeope.app.core.fcm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.yeope.app.MainActivity
import com.yeope.app.R
import com.yeope.app.core.token.TokenManager
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@AndroidEntryPoint
class YeopeFirebaseMessagingService : FirebaseMessagingService() {

    @Inject lateinit var tokenManager: TokenManager
    @Inject lateinit var authRepository: com.yeope.app.feature.auth.data.AuthRepository

    override fun onNewToken(token: String) {
        Log.d(TAG, "Refreshed token: $token")
        // Sync with server if logged in
        if (tokenManager.getAccessToken() != null) {
            CoroutineScope(Dispatchers.IO).launch {
                authRepository.updateProfile(
                    nickname = null,
                    nicknameMask = null,
                    fcmToken = token
                ).collect {
                    Log.d(TAG, "Token synced with server: $it")
                }
            }
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "From: ${remoteMessage.from}")

        // Check data payload
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${remoteMessage.data}")
            handleNotification(remoteMessage.data)
        }

        // Check notification payload (foreground manual handling not usually needed if data payload handles it, 
        // but for pure simple notifications, system handles it in BG. In FG, we manually show.)
        // We prefer Data payloads for deep linking.
    }

    private fun handleNotification(data: Map<String, String>) {
        val type = data["type"]
        val title = data["title"] ?: "New Notification"
        val body = data["body"] ?: "You have a new message"
        val roomId = data["roomId"]
        val roomName = data["roomName"] ?: "Chat"

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // Deep Link Extras
            when (type) {
                "new_message", "room_invite" -> {
                    if (roomId != null) {
                        putExtra("navigation_target", "chat")
                        putExtra("roomId", roomId)
                        putExtra("roomName", roomName)
                    }
                }
                "nearby_user" -> {
                    putExtra("navigation_target", "home")
                }
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT
        )

        val channelId = getString(R.string.default_notification_channel_id)
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setSound(defaultSoundUri)
            .setContentIntent(pendingIntent)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "YEO.PE Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }

    companion object {
        private const val TAG = "YeopeFCM"
    }
}
