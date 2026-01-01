package com.yeope.app.feature.chat.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.yeope.app.feature.auth.data.AuthRepository
import com.yeope.app.feature.chat.data.ChatMessage
import com.yeope.app.feature.chat.data.ChatRepository
import com.yeope.app.core.token.TokenManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import java.util.UUID
import java.time.format.DateTimeFormatter
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository,
    private val tokenManager: TokenManager
) : ViewModel() {

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    private val _typingUserIds = MutableStateFlow<Set<String>>(emptySet())
    val typingUserIds: StateFlow<Set<String>> = _typingUserIds.asStateFlow()
    
    private val _isTyping = MutableStateFlow(false)
    private var typingJob: Job? = null

    init {
        observeSocketEvents()
    }

    private fun observeSocketEvents() {
        viewModelScope.launch {
            chatRepository.observeMessages().collect { message ->
                // Check if we already have this ID (optimistic update confirmation)
                val currentList = _messages.value.toMutableList()
                val index = currentList.indexOfFirst { it.id == message.id }
                
                if (index != -1) {
                    // Update existing (e.g. from SENDING to SENT)
                    // In a real app, strict parity might match ID or temp ID. 
                    // iOS uses temp UUID for optimistic, then separate ID from server? 
                    // Actually iOS checks `if let index = self.messages.firstIndex(where: { $0.id == message.id }) { return }`
                    // It ignores if ID exists.
                    // For optimistic, we need a way to dedupe. 
                    // Simplification: just append if not exists.
                    // If we used a temp ID, we'd replace it.
                    currentList[index] = message // Replace the temporary message with the confirmed one
                    _messages.value = currentList
                } else {
                    _messages.value = _messages.value + message
                }
            }
        }
        
        viewModelScope.launch {
            chatRepository.observeTyping().collect { event ->
                val current = _typingUserIds.value.toMutableSet()
                if (event.userId != tokenManager.getUserId()) {
                    if (event.isTyping) current.add(event.userId)
                    else current.remove(event.userId)
                    _typingUserIds.value = current
                }
            }
        }
    }

    fun connect() {
        chatRepository.connect()
    }
    
    fun disconnect() {
        chatRepository.disconnect()
    }

    fun joinRoom(roomId: String) {
        chatRepository.joinRoom(roomId)
        fetchMessages(roomId)
    }
    
    fun fetchMessages(roomId: String) {
        viewModelScope.launch {
            chatRepository.getMessageHistory(roomId).collect { result ->
                result.onSuccess { history ->
                    _messages.value = history
                }.onFailure {
                    // Log error
                }
            }
        }
    }

    fun onTextInput(roomId: String, text: String) {
        if (!_isTyping.value) {
            _isTyping.value = true
            chatRepository.sendTypingStart(roomId)
        }

        typingJob?.cancel()
        typingJob = viewModelScope.launch {
            delay(3000)
            _isTyping.value = false
            chatRepository.sendTypingEnd(roomId)
        }
    }

    fun sendMessage(roomId: String, content: String) {
        // Optimistic Update
        val myId = tokenManager.getUserId() ?: ""
        val tempMessage = ChatMessage(
            id = UUID.randomUUID().toString(), // Temp ID
            content = content,
            userId = myId,
            nickname = "Me", // Placeholder, ideally fetch from profile
            nicknameMask = null,
            type = "text",
            createdAt = DateTimeFormatter.ISO_INSTANT.format(java.time.Instant.now()),
            localStatus = com.yeope.app.feature.chat.data.LocalStatus.SENDING
        )
        
        _messages.value = _messages.value + tempMessage
        
        // Actual Send
        chatRepository.sendMessage(roomId, content)
    }
}
