package com.yeope.app.feature.auth.domain

import com.yeope.app.feature.auth.data.AuthRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class LoginUseCase @Inject constructor(
    private val authRepository: AuthRepository
) {
    operator fun invoke(email: String, nickname: String): Flow<Result<Unit>> {
        return authRepository.login(email, nickname)
    }
}
