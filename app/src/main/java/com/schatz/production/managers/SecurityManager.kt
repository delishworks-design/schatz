package com.schatz.production.managers

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecurityManager(private val context: Context) {
    private val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
    private val encryptedPrefs = EncryptedSharedPreferences.create(context, "schatz_secure_prefs", masterKey, EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV, EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)

    fun setPin(pin: String) { encryptedPrefs.edit().putString("app_pin", pin).apply() }
    fun verifyPin(pin: String): Boolean { return encryptedPrefs.getString("app_pin", null) == pin }
    fun isBiometricAvailable(): Boolean {
        val biometricManager = BiometricManager.from(context)
        return biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
    }
    fun isAppLockEnabled(): Boolean { return encryptedPrefs.getBoolean("app_lock_enabled", false) }
    fun setAppLockEnabled(enabled: Boolean) { encryptedPrefs.edit().putBoolean("app_lock_enabled", enabled).apply() }
    fun isEncryptionEnabled(): Boolean { return encryptedPrefs.getBoolean("encrypt_vault", true) }
    fun clearOnLogout() {
        encryptedPrefs.edit().clear().apply()
        context.filesDir.listFiles()?.forEach { file -> if(file.name.startsWith("vault_")) file.deleteRecursively() }
    }
    fun saveSession(key: String, value: String) { encryptedPrefs.edit().putString(key, value).apply() }
    fun getSession(key: String): String? { return encryptedPrefs.getString(key, null) }
}
