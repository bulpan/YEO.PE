package com.yeope.app.feature.chat.data

import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RoomRepository @Inject constructor(
    private val roomService: RoomService
) {

    suspend fun createRoom(otherUserId: String): Result<RoomResponse> {
        return try {
            val response = roomService.createRoom(CreateRoomRequest(otherUserId))
            if (response.isSuccessful) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to create room: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getMyRooms(): Result<List<RoomResponse>> {
        return try {
            val response = roomService.getMyRooms()
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Failed to fetch rooms: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
