package com.schatz.production.managers
import android.content.Context
import android.media.AudioManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
enum class AudioRoute { EARPIECE, SPEAKER, BLUETOOTH, WIRED_HEADSET }
enum class CameraError { NONE, NOT_AVAILABLE, PERMISSION_DENIED, IN_USE, UNKNOWN }
enum class MicError { NONE, NOT_AVAILABLE, PERMISSION_DENIED, IN_USE, UNKNOWN }
class CallEnhancedManager(context: Context, private val callManager: CallManager) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val _audioRoute = MutableStateFlow(AudioRoute.EARPIECE)
    val audioRoute: StateFlow<AudioRoute> = _audioRoute
    private val _isBluetoothAvailable = MutableStateFlow(false)
    val isBluetoothAvailable: StateFlow<Boolean> = _isBluetoothAvailable
    private val _cameraError = MutableStateFlow(CameraError.NONE)
    val cameraError: StateFlow<CameraError> = _cameraError
    private val _micError = MutableStateFlow(MicError.NONE)
    val micError: StateFlow<MicError> = _micError
    fun setAudioRoute(route: AudioRoute) { _audioRoute.value=route; when(route){AudioRoute.EARPIECE->{audioManager.isSpeakerphoneOn=false; audioManager.isBluetoothScoOn=false; audioManager.stopBluetoothSco()}; AudioRoute.SPEAKER->{audioManager.isSpeakerphoneOn=true; audioManager.isBluetoothScoOn=false; audioManager.stopBluetoothSco()}; AudioRoute.BLUETOOTH->{audioManager.isSpeakerphoneOn=false; audioManager.startBluetoothSco(); audioManager.isBluetoothScoOn=true}; AudioRoute.WIRED_HEADSET->{audioManager.isSpeakerphoneOn=false; audioManager.isBluetoothScoOn=false} } }
    fun handleCameraError(error: Exception): CameraError { val e=when{error.message?.contains("permission",true)==true->CameraError.PERMISSION_DENIED; error.message?.contains("in use",true)==true->CameraError.IN_USE; else->CameraError.UNKNOWN}; _cameraError.value=e; return e }
    fun handleMicError(error: Exception): MicError { val e=when{error.message?.contains("permission",true)==true->MicError.PERMISSION_DENIED; error.message?.contains("in use",true)==true->MicError.IN_USE; else->MicError.UNKNOWN}; _micError.value=e; return e }
    fun getCameraErrorMessage(): String { return when(_cameraError.value){CameraError.PERMISSION_DENIED->"Camera permission denied. Enable in settings."; CameraError.IN_USE->"Camera in use by another app."; else->"Camera error."} }
    fun getMicErrorMessage(): String { return when(_micError.value){MicError.PERMISSION_DENIED->"Microphone permission denied."; MicError.IN_USE->"Mic in use."; else->"Mic error."} }
    fun clearErrors() { _cameraError.value=CameraError.NONE; _micError.value=MicError.NONE }
}
