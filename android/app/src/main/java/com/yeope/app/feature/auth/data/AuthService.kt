package com.yeope.app.feature.auth.data

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.GET
import retrofit2.http.PATCH

interface AuthService {
    @POST("auth/login/classic")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>

    @POST("auth/register/classic")
    suspend fun register(@Body request: RegisterRequest): Response<LoginResponse>

    @GET("auth/me")
    suspend fun getUserProfile(): Response<UserResponse>

    @PATCH("users/me")
    suspend fun updateUser(@Body request: UpdateUserRequest): Response<UserResponse>

    @POST("users/me/mask")
    suspend fun regenerateMask(): Response<UserResponse>

    // Safety Features
    @POST("users/block")
    suspend fun blockUser(@Body request: BlockUserRequest): Response<Unit>

    @POST("users/unblock")
    suspend fun unblockUser(@Body request: UnblockUserRequest): Response<Unit>

    @GET("users/blocked")
    suspend fun getBlockedUsers(): Response<BlockedUsersResponse>

    @POST("reports")
    suspend fun reportUser(@Body request: ReportUserRequest): Response<Unit>
}

data class LoginRequest(val email: String, val nickname: String)
data class RegisterRequest(val email: String, val nickname: String)
data class UpdateUserRequest(val nickname: String?, val nicknameMask: String?, val fcmToken: String?, val settings: UserSettingsDto? = null)

data class UserSettingsDto(val bleVisible: Boolean, val pushEnabled: Boolean)

// Shared Response Wrapper for User Data
data class UserResponse(val user: UserDto)

data class LoginResponse(
    val token: String,
    val user: UserDto
)
data class UserDto(
    val id: String, 
    val nickname: String, 
    val nicknameMask: String? = null,
    val email: String
)

data class BlockUserRequest(val targetUserId: String)
data class UnblockUserRequest(val targetUserId: String)
data class ReportUserRequest(val targetUserId: String, val reason: String, val details: String? = null)

data class BlockedUsersResponse(val blockedUsers: List<BlockedUserDto>)
data class BlockedUserDto(val id: String, val nickname: String, val blockedAt: String)
