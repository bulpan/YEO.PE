package com.yeope.app.feature.chat.data

import android.util.Log
import com.yeope.app.core.socket.SocketManager
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChatRepository @Inject constructor(
    private val socketManager: SocketManager,
    private val chatService: ChatService
) {
    
    fun connect() {
        socketManager.connect()
    }
    
    fun disconnect() {
        socketManager.disconnect()
    }

    fun joinRoom(roomId: String) {
        val data = JSONObject().apply {
            put("roomId", roomId)
        }
        socketManager.emit("join_room", data)
    }
    
    fun sendMessage(roomId: String, content: String) {
        val data = JSONObject().apply {
            put("roomId", roomId)
            put("content", content)
            put("type", "text")
        }
        socketManager.emit("message", data)
    }

    fun sendTypingStart(roomId: String) {
        val data = JSONObject().apply { put("roomId", roomId) }
        socketManager.emit("typing_start", data)
    }

    fun sendTypingEnd(roomId: String) {
        val data = JSONObject().apply { put("roomId", roomId) }
        socketManager.emit("typing_end", data)
    }

    // HTTP Fetch
    fun getMessageHistory(roomId: String): Flow<Result<List<ChatMessage>>> = kotlinx.coroutines.flow.flow {
        try {
            val response = chatService.getMessages(roomId)
            if (response.isSuccessful && response.body() != null) {
                val dtos = response.body()!!.messages
                val mapped = dtos.map { dto ->
                    ChatMessage(
                        id = dto.id,
                        content = dto.content,
                        userId = dto.userId, // iOS Key
                        nickname = dto.nickname,
                        nicknameMask = dto.nicknameMask,
                        type = dto.type,
                        createdAt = dto.createdAt,
                        imageUrl = dto.imageUrl,
                        localStatus = LocalStatus.SENT
                    )
                }
                emit(Result.success(mapped))
            } else {
                emit(Result.failure(Exception("Failed to fetch history: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    // Socket Events
    fun observeMessages(): Flow<ChatMessage> = callbackFlow {
        socketManager.on("new-message") { args ->
            val data = args.firstOrNull() as? JSONObject ?: return@on
            try {
                // Parse keys matching iOS socket payload
                val message = ChatMessage(
                    id = data.optString("id"),
                    content = data.optString("content"),
                    userId = data.optString("userId"), 
                    nickname = data.optString("nickname").takeIf { it.isNotEmpty() },
                    nicknameMask = data.optString("nicknameMask").takeIf { it.isNotEmpty() },
                    type = data.optString("type", "text"),
                    createdAt = data.optString("created_at"),
                    imageUrl = data.optString("imageUrl", null),
                    localStatus = LocalStatus.SENT
                )
                trySend(message)
            } catch (e: Exception) {
                Log.e("ChatRepository", "Message parsing error", e)
            }
        }
        awaitClose { socketManager.off("new-message") }
    }
    
    fun observeTyping(): Flow<TypingEvent> = callbackFlow {
        socketManager.on("typing_update") { args ->
            val data = args.firstOrNull() as? JSONObject ?: return@on
            val userId = data.optString("userId")
            val isTyping = data.optBoolean("isTyping")
            if (userId.isNotEmpty()) {
                trySend(TypingEvent(userId, isTyping))
            }
        }
        awaitClose { socketManager.off("typing_update") }
    }
}

data class TypingEvent(val userId: String, val isTyping: Boolean)

data class ChatMessage(
    val id: String,
    val content: String,
    val userId: String,
    val nickname: String?,
    val nicknameMask: String?,
    val type: String,
    val createdAt: String,
    val imageUrl: String? = null,
    val localStatus: LocalStatus = LocalStatus.SENT
)

enum class LocalStatus { SENDING, SENT, FAILED }
