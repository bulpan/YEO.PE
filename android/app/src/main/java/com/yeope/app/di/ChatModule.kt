package com.yeope.app.di

import com.yeope.app.core.socket.SocketManager
import com.yeope.app.feature.chat.data.ChatRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object ChatModule {

    // ChatRepository is provided via @Inject constructor

}
