package com.yeope.app.feature.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.yeope.app.feature.auth.data.AuthRepository
import com.yeope.app.feature.auth.data.BlockedUserDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class BlockedUsersUiState(
    val blockedUsers: List<BlockedUserDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class BlockedUsersViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(BlockedUsersUiState())
    val uiState: StateFlow<BlockedUsersUiState> = _uiState.asStateFlow()

    init {
        loadBlockedUsers()
    }

    fun loadBlockedUsers() {
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            authRepository.getBlockedUsers().collect { result ->
                result.onSuccess { users ->
                    _uiState.value = _uiState.value.copy(blockedUsers = users, isLoading = false)
                }.onFailure { e ->
                    _uiState.value = _uiState.value.copy(error = e.message, isLoading = false)
                }
            }
        }
    }

    fun unblockUser(userId: String) {
        viewModelScope.launch {
            authRepository.unblockUser(userId).collect { result ->
                result.onSuccess {
                    // Reload list after unblocking
                    loadBlockedUsers()
                }.onFailure { e ->
                    _uiState.value = _uiState.value.copy(error = "Unblock failed: ${e.message}")
                }
            }
        }
    }
}
