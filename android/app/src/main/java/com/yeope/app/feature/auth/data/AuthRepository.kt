package com.yeope.app.feature.auth.data

import com.yeope.app.core.token.TokenManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

class AuthRepository @Inject constructor(
    private val authService: AuthService,
    private val tokenManager: TokenManager
) {

    fun login(email: String, nickname: String): Flow<Result<Unit>> = flow {
        try {
            val response = authService.login(LoginRequest(email, nickname))
            if (response.isSuccessful && response.body() != null) {
                val body = response.body()!!
                tokenManager.saveAccessToken(body.token)
                tokenManager.saveUserId(body.user.id)
                emit(Result.success(Unit))
            } else {
                emit(Result.failure(Exception("Login failed: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun register(email: String, nickname: String): Flow<Result<Unit>> = flow {
        try {
            val response = authService.register(RegisterRequest(email, nickname))
            if (response.isSuccessful && response.body() != null) {
                val body = response.body()!!
                tokenManager.saveAccessToken(body.token)
                tokenManager.saveUserId(body.user.id)
                emit(Result.success(Unit))
            } else {
                emit(Result.failure(Exception("Register failed: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun updateProfile(nickname: String?, nicknameMask: String?, fcmToken: String?): Flow<Result<Unit>> = flow {
        try {
            val response = authService.updateUser(UpdateUserRequest(nickname, nicknameMask, fcmToken))
            if (response.isSuccessful && response.body() != null) {
                emit(Result.success(Unit))
            } else {
                emit(Result.failure(Exception("Update failed: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun getUserProfile(): Flow<Result<UserDto>> = flow {
        try {
            val response = authService.getUserProfile()
            if (response.isSuccessful && response.body() != null) {
                emit(Result.success(response.body()!!.user))
            } else {
                emit(Result.failure(Exception("Get Profile failed: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun regenerateMask(): Flow<Result<String>> = flow {
        try {
            val response = authService.regenerateMask()
            if (response.isSuccessful && response.body() != null) {
                // Return new mask
                emit(Result.success(response.body()!!.user.nicknameMask ?: "?"))
            } else {
                emit(Result.failure(Exception("Regenerate failed: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    // Safety
    fun blockUser(targetUserId: String): Flow<Result<Unit>> = flow {
        try {
            val response = authService.blockUser(BlockUserRequest(targetUserId))
            if (response.isSuccessful) emit(Result.success(Unit))
            else emit(Result.failure(Exception("Block failed: ${response.code()}")))
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun unblockUser(targetUserId: String): Flow<Result<Unit>> = flow {
        try {
            val response = authService.unblockUser(UnblockUserRequest(targetUserId))
            if (response.isSuccessful) emit(Result.success(Unit))
            else emit(Result.failure(Exception("Unblock failed: ${response.code()}")))
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun getBlockedUsers(): Flow<Result<List<BlockedUserDto>>> = flow {
        try {
            val response = authService.getBlockedUsers()
            if (response.isSuccessful && response.body() != null) {
                emit(Result.success(response.body()!!.blockedUsers))
            } else {
                emit(Result.failure(Exception("Get Blocked Users failed: ${response.code()}")))
            }
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }

    fun reportUser(targetUserId: String, reason: String, details: String?): Flow<Result<Unit>> = flow {
        try {
            val response = authService.reportUser(ReportUserRequest(targetUserId, reason, details))
            if (response.isSuccessful) emit(Result.success(Unit))
            else emit(Result.failure(Exception("Report failed: ${response.code()}")))
        } catch (e: Exception) {
            emit(Result.failure(e))
        }
    }
}
