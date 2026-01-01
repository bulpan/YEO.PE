package com.yeope.app.di

import com.yeope.app.core.token.EncryptedTokenManager
import com.yeope.app.core.token.TokenManager
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class CoreModule {

    @Binds
    @Singleton
    abstract fun bindTokenManager(
        tokenManager: EncryptedTokenManager
    ): TokenManager
}
