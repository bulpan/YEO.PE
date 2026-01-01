package com.yeope.app.feature.chat.data

import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

interface ChatService {
    @GET("rooms/{roomId}/messages")
    suspend fun getMessages(
        @Path("roomId") roomId: String,
        @Query("before") before: String? = null,
        @Query("limit") limit: Int = 50
    ): Response<MessageListResponse>
}

data class MessageListResponse(
    val messages: List<ChatMessageDto>
)

data class ChatMessageDto(
    val id: String,
    val content: String,
    val userId: String, // iOS Key: userId (not senderId)
    val nickname: String?,
    val nicknameMask: String?,
    val type: String = "text",
    val createdAt: String,
    val imageUrl: String? = null
)
