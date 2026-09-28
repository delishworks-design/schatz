package com.schatz.production.managers

import android.content.Context
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class RecordingState { IDLE, RECORDING, PAUSED, CANCELLED }
enum class PlaybackState { IDLE, PLAYING, PAUSED, STOPPED }

data class VoiceMessage(
    val id: String,
    val filePath: String,
    val duration: Int, // seconds
    val waveform: List<Int> = emptyList(), // amplitudes for waveform
    val isFromMe: Boolean,
    val timestamp: Long
)

class VoiceMessageManager(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null

    private val _recordingState = MutableStateFlow(RecordingState.IDLE)
    val recordingState: StateFlow<RecordingState> = _recordingState

    private val _playbackState = MutableStateFlow(PlaybackState.IDLE)
    val playbackState: StateFlow<PlaybackState> = _playbackState

    private val _recordingDuration = MutableStateFlow(0)
    val recordingDuration: StateFlow<Int> = _recordingDuration

    private val _playbackProgress = MutableStateFlow(0)
    val playbackProgress: StateFlow<Int> = _playbackProgress

    private val _amplitudes = MutableStateFlow<List<Int>>(emptyList())
    val amplitudes: StateFlow<List<Int>> = _amplitudes

    private var currentRecordingFile: File? = null
    private var recordingTimer: java.util.Timer? = null
    private var playbackTimer: java.util.Timer? = null

    fun startRecording() {
        try {
            val dir = File(context.filesDir, "voice_messages").apply { mkdirs() }
            currentRecordingFile = File(dir, "voice_${System.currentTimeMillis()}.m4a")

            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(currentRecordingFile!!.absolutePath)
                prepare()
                start()
            }

            _recordingState.value = RecordingState.RECORDING
            _recordingDuration.value = 0
            _amplitudes.value = emptyList()

            recordingTimer?.cancel()
            recordingTimer = java.util.Timer()
            recordingTimer?.scheduleAtFixedRate(object : java.util.TimerTask() {
                override fun run() {
                    _recordingDuration.value += 1
                    // Simulate waveform amplitude (real would use recorder.maxAmplitude)
                    val amp = try { recorder?.maxAmplitude ?: 0 } catch(e: Exception) { 0 }
                    val normalized = (amp / 1000).coerceIn(0, 30)
                    val current = _amplitudes.value.toMutableList()
                    current.add(normalized)
                    if(current.size > 50) current.removeAt(0)
                    _amplitudes.value = current
                }
            }, 0, 100)

        } catch (e: Exception) {
            _recordingState.value = RecordingState.IDLE
            android.util.Log.e("VoiceManager", "Recording failed", e)
        }
    }

    fun stopRecording(): File? {
        try {
            recorder?.stop()
            recorder?.release()
            recorder = null
            recordingTimer?.cancel()
            _recordingState.value = RecordingState.IDLE
            return currentRecordingFile
        } catch (e: Exception) {
            _recordingState.value = RecordingState.IDLE
            return null
        }
    }

    fun cancelRecording() {
        try {
            recorder?.stop()
            recorder?.release()
            recorder = null
            recordingTimer?.cancel()
            currentRecordingFile?.delete()
            currentRecordingFile = null
            _recordingState.value = RecordingState.CANCELLED
            _recordingDuration.value = 0
            _amplitudes.value = emptyList()
        } catch (e: Exception) {
            _recordingState.value = RecordingState.IDLE
        }
    }

    fun startPlayback(filePath: String) {
        try {
            player?.release()
            player = MediaPlayer().apply {
                setDataSource(filePath)
                prepare()
                start()
            }

            _playbackState.value = PlaybackState.PLAYING
            _playbackProgress.value = 0

            val duration = player?.duration ?: 0

            playbackTimer?.cancel()
            playbackTimer = java.util.Timer()
            playbackTimer?.scheduleAtFixedRate(object : java.util.TimerTask() {
                override fun run() {
                    try {
                        val current = player?.currentPosition ?: 0
                        _playbackProgress.value = if(duration > 0) (current * 100 / duration) else 0
                        if(current >= duration) {
                            _playbackState.value = PlaybackState.STOPPED
                            playbackTimer?.cancel()
                        }
                    } catch(e: Exception) {
                        _playbackState.value = PlaybackState.STOPPED
                    }
                }
            }, 0, 100)

            player?.setOnCompletionListener {
                _playbackState.value = PlaybackState.STOPPED
                _playbackProgress.value = 100
                playbackTimer?.cancel()
            }

        } catch (e: Exception) {
            _playbackState.value = PlaybackState.IDLE
            android.util.Log.e("VoiceManager", "Playback failed", e)
        }
    }

    fun pausePlayback() {
        try {
            player?.pause()
            _playbackState.value = PlaybackState.PAUSED
            playbackTimer?.cancel()
        } catch(e: Exception) {}
    }

    fun resumePlayback() {
        try {
            player?.start()
            _playbackState.value = PlaybackState.PLAYING
            playbackTimer = java.util.Timer()
            playbackTimer?.scheduleAtFixedRate(object : java.util.TimerTask() {
                override fun run() {
                    try {
                        val current = player?.currentPosition ?: 0
                        val duration = player?.duration ?: 1
                        _playbackProgress.value = current * 100 / duration
                    } catch(e: Exception) {}
                }
            }, 0, 100)
        } catch(e: Exception) {}
    }

    fun seekTo(progress: Int) {
        try {
            val duration = player?.duration ?: 0
            val seekPos = duration * progress / 100
            player?.seekTo(seekPos)
            _playbackProgress.value = progress
        } catch(e: Exception) {}
    }

    fun stopPlayback() {
        try {
            player?.stop()
            player?.release()
            player = null
            playbackTimer?.cancel()
            _playbackState.value = PlaybackState.STOPPED
            _playbackProgress.value = 0
        } catch(e: Exception) {}
    }

    fun cleanup() {
        try {
            recorder?.release()
            player?.release()
            recordingTimer?.cancel()
            playbackTimer?.cancel()
        } catch(e: Exception) {}
    }
}
