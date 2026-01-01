package com.yeope.app.core.socket

import android.util.Log
import com.yeope.app.core.token.TokenManager
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton
import java.net.URI

@Singleton
class SocketManager @Inject constructor(
    private val tokenManager: TokenManager
) {

    private var socket: Socket? = null
    // Use the actual IP address for physical device testing
    private val SOCKET_URL = "http://192.168.219.112:3000"

    fun connect() {
        if (socket?.connected() == true) return

        val token = tokenManager.getAccessToken() ?: return

        try {
            val options = IO.Options().apply {
                forceNew = true
                query = "token=$token"
                transports = arrayOf("websocket") // Force WebSocket for better performance
            }
            
            // Re-create socket instance to ensure fresh options
            socket = IO.socket(URI.create(SOCKET_URL), options)
            
            setupListeners()
            socket?.connect()
            Log.d("SocketManager", "Connecting to $SOCKET_URL...")

        } catch (e: Exception) {
            Log.e("SocketManager", "Connection error", e)
        }
    }

    private fun setupListeners() {
        socket?.on(Socket.EVENT_CONNECT) {
            Log.d("SocketManager", "✅ Connected!")
        }
        
        socket?.on(Socket.EVENT_CONNECT_ERROR) { args ->
            Log.e("SocketManager", "❌ Connection Error: ${args.firstOrNull()}")
        }
        
        socket?.on(Socket.EVENT_DISCONNECT) {
            Log.d("SocketManager", "⚠️ Disconnected")
        }
    }

    fun disconnect() {
        socket?.disconnect()
        socket?.off()
        socket = null
    }

    fun isConnected(): Boolean = socket?.connected() == true

    fun on(event: String, listener: (Array<Any>) -> Unit) {
        socket?.on(event) { args ->
            listener(args)
        }
    }

    fun off(event: String) {
        socket?.off(event)
    }

    fun emit(event: String, data: JSONObject) {
        socket?.emit(event, data)
    }
}
