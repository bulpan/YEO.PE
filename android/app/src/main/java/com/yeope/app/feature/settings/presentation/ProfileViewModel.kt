package com.yeope.app.feature.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.yeope.app.core.token.TokenManager
import com.yeope.app.feature.auth.data.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProfileUiState(
    val nickname: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val isSaved: Boolean = false
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val tokenManager: TokenManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        fetchUserProfile()
    }

    private fun fetchUserProfile() {
        _uiState.value = _uiState.value.copy(isLoading = true)
        viewModelScope.launch {
            authRepository.getUserProfile().collect { result ->
                result.onSuccess { user ->
                    _uiState.value = _uiState.value.copy(
                        nickname = user.nicknameMask ?: user.nickname, // Prefer mask for public display default
                        isLoading = false
                    )
                }.onFailure {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                }
            }
        }
    }

    fun updateNickname(newName: String) {
        _uiState.value = _uiState.value.copy(nickname = newName)
    }

    fun saveProfile() {
        val currentName = _uiState.value.nickname
        if (currentName.isBlank()) return

        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        // Spec says we update 'nicknameMask' for visual identity in Radar? 
        // Or if user edits 'nickname' (real name) vs 'mask'?
        // ProfileEditView.swift creates a random mask OR edits specific nicknameMask.
        // Let's assume we are editing the MASK which is the public identity.
        viewModelScope.launch {
            authRepository.updateProfile(nickname = null, nicknameMask = currentName, fcmToken = null)
                .collect { result ->
                    result.onSuccess {
                        _uiState.value = _uiState.value.copy(isLoading = false, isSaved = true)
                    }.onFailure { e ->
                        _uiState.value = _uiState.value.copy(isLoading = false, error = e.message)
                    }
                }
        }
    }

    fun randomizeMask() {
        _uiState.value = _uiState.value.copy(isLoading = true)
        viewModelScope.launch {
            authRepository.regenerateMask().collect { result ->
                result.onSuccess { newMask ->
                    _uiState.value = _uiState.value.copy(nickname = newMask, isLoading = false)
                }.onFailure { e ->
                    // Fallback or Error
                     _uiState.value = _uiState.value.copy(isLoading = false, error = e.message)
                }
            }
        }
    }
    
    fun resetSavedState() {
        _uiState.value = _uiState.value.copy(isSaved = false)
    }
}
