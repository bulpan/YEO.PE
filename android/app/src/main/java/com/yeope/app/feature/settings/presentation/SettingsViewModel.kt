package com.yeope.app.feature.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.yeope.app.core.data.UserPreferencesRepository
import com.yeope.app.core.token.TokenManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val isDarkMode: Boolean = true,
    val isPushEnabled: Boolean = true,
    val messageRetention: String = "24h",
    val roomExitCondition: String = "24h",
    val userId: String = "Unknown",
    val userName: String = "Unknown User", // Placeholder until connected to Real User Profile API
    val userEmail: String = "email@hidden.com" // Placeholder
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val userPreferencesRepository: UserPreferencesRepository,
    private val tokenManager: TokenManager
) : ViewModel() {

    // Combine multiple data sources into a single UI State
    val uiState: StateFlow<SettingsUiState> = combine(
        userPreferencesRepository.isDarkMode,
        userPreferencesRepository.isPushEnabled,
        userPreferencesRepository.messageRetention,
        userPreferencesRepository.roomExitCondition
    ) { isDarkMode, isPushEnabled, retention, exitCondition ->
        SettingsUiState(
            isDarkMode = isDarkMode,
            isPushEnabled = isPushEnabled,
            messageRetention = retention,
            roomExitCondition = exitCondition,
            userId = tokenManager.getUserId() ?: "Start scanning...",
            // TODO: Fetch real name/email from API or decode JWT
            // For now, we use a placeholder that indicates "Guest" or "User"
            userName = if (tokenManager.isLoggedIn()) "YeoPe User" else "Guest",
            userEmail = if (tokenManager.isLoggedIn()) "private@relay.apple.com" else "No Email"
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = SettingsUiState()
    )

    fun toggleDarkMode(enabled: Boolean) {
        viewModelScope.launch {
            userPreferencesRepository.setDarkMode(enabled)
        }
    }

    fun togglePush(enabled: Boolean) {
        viewModelScope.launch {
            userPreferencesRepository.setPushEnabled(enabled)
        }
    }
    
    fun setRetention(value: String) {
        viewModelScope.launch {
            userPreferencesRepository.setMessageRetention(value)
        }
    }

    fun setRoomExitCondition(value: String) {
        viewModelScope.launch {
            userPreferencesRepository.setRoomExitCondition(value)
        }
    }
}
