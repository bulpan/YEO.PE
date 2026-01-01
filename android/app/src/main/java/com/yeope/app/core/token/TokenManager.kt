package com.yeope.app.core.token

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

interface TokenManager {
    fun getAccessToken(): String?
    fun saveAccessToken(token: String)
    fun clearAccessToken()
    fun isLoggedIn(): Boolean
    
    fun getUserId(): String?
    fun saveUserId(id: String)
    fun clearUserId()
}

@Singleton
class EncryptedTokenManager @Inject constructor(
    @ApplicationContext private val context: Context
) : TokenManager {

    companion object {
        private const val PREFS_NAME = "secure_prefs"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_USER_ID = "user_id"
    }

    private val sharedPreferences: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    override fun getAccessToken(): String? {
        return sharedPreferences.getString(KEY_ACCESS_TOKEN, null)
    }

    override fun saveAccessToken(token: String) {
        sharedPreferences.edit().putString(KEY_ACCESS_TOKEN, token).apply()
    }

    override fun clearAccessToken() {
        sharedPreferences.edit().remove(KEY_ACCESS_TOKEN).apply()
    }

    override fun isLoggedIn(): Boolean {
        return getAccessToken() != null
    }

    override fun getUserId(): String? {
        return sharedPreferences.getString(KEY_USER_ID, null)
    }

    override fun saveUserId(id: String) {
        sharedPreferences.edit().putString(KEY_USER_ID, id).apply()
    }

    override fun clearUserId() {
        sharedPreferences.edit().remove(KEY_USER_ID).apply()
    }
}
