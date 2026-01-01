package com.yeope.app.core.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")

@Singleton
class UserPreferencesRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private object PreferencesKeys {
        val DARK_MODE = booleanPreferencesKey("dark_mode")
        val PUSH_ENABLED = booleanPreferencesKey("push_enabled")
        val LANGUAGE = stringPreferencesKey("language")
        val MESSAGE_RETENTION = stringPreferencesKey("message_retention")
        val ROOM_EXIT_CONDITION = stringPreferencesKey("room_exit_condition")
    }

    // Read Data
    val isDarkMode: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[PreferencesKeys.DARK_MODE] ?: true // Default to Dark Mode
    }

    val isPushEnabled: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[PreferencesKeys.PUSH_ENABLED] ?: true
    }
    
    val messageRetention: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[PreferencesKeys.MESSAGE_RETENTION] ?: "24h"
    }

    val roomExitCondition: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[PreferencesKeys.ROOM_EXIT_CONDITION] ?: "24h"
    }

    // Write Data
    suspend fun setDarkMode(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.DARK_MODE] = enabled
        }
    }

    suspend fun setPushEnabled(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.PUSH_ENABLED] = enabled
        }
    }
    
    suspend fun setMessageRetention(value: String) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.MESSAGE_RETENTION] = value
        }
    }

    suspend fun setRoomExitCondition(value: String) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.ROOM_EXIT_CONDITION] = value
        }
    }
}
