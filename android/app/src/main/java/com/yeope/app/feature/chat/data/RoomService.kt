package com.yeope.app.feature.chat.data

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface RoomService {
    @POST("rooms")
    suspend fun createRoom(@Body request: CreateRoomRequest): Response<RoomResponse>

    @GET("rooms")
    suspend fun getMyRooms(): Response<List<RoomResponse>>
}

data class CreateRoomRequest(
    val otherUserId: String
)

data class RoomResponse(
    val _id: String,
    val type: String,
    val participants: List<String>
    // add other fields if needed
)
