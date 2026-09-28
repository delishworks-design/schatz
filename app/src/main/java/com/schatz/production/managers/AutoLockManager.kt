package com.schatz.production.managers
import android.content.Context
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
enum class AutoLockTimeout { IMMEDIATE, THIRTY_SECONDS, ONE_MINUTE, FIVE_MINUTES, NEVER }
class AutoLockManager(context: Context, private val securityManager: SecurityManager) {
    private val _isLocked = MutableStateFlow(false)
    val isLocked: StateFlow<Boolean> = _isLocked
    private val _timeout = MutableStateFlow(AutoLockTimeout.ONE_MINUTE)
    val timeout: StateFlow<AutoLockTimeout> = _timeout
    private var lockHandler = Handler(Looper.getMainLooper())
    private var lockRunnable: Runnable? = null
    fun setTimeout(timeout: AutoLockTimeout) { _timeout.value=timeout; securityManager.saveSession("auto_lock_timeout", timeout.name); resetTimer() }
    fun resetTimer() { lockRunnable?.let{lockHandler.removeCallbacks(it)}; if(_timeout.value==AutoLockTimeout.NEVER || !securityManager.isAppLockEnabled()) return; val delay=when(_timeout.value){AutoLockTimeout.IMMEDIATE->0L;AutoLockTimeout.THIRTY_SECONDS->30_000L;AutoLockTimeout.ONE_MINUTE->60_000L;AutoLockTimeout.FIVE_MINUTES->300_000L;AutoLockTimeout.NEVER->return}; lockRunnable=Runnable{lock()}; lockHandler.postDelayed(lockRunnable!!, delay) }
    fun lock() { if(securityManager.isAppLockEnabled()) _isLocked.value=true }
    fun unlock(pin: String): Boolean { val v=securityManager.verifyPin(pin); if(v){_isLocked.value=false; resetTimer()}; return v }
    fun onAppBackgrounded() { if(_timeout.value==AutoLockTimeout.IMMEDIATE) lock() }
    fun cancelTimer() { lockRunnable?.let{lockHandler.removeCallbacks(it)} }
}
