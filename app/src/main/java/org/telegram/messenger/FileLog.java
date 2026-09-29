package org.telegram.messenger;

/**
 * Compile-time shim for Telegram's FileLog, referenced by the vendored org.webrtc sources
 * (EglRenderer, GlGenericDrawer, HardwareVideoEncoder, YuvConverter, ScreenCapturerAndroid,
 * audio/WebRtcAudioTrack, voiceengine/*). Routes to android.util.Log.
 */
public final class FileLog {
    private FileLog() {}

    public static void d(String message) {
        android.util.Log.d("WebRTC", message == null ? "" : message);
    }

    public static void e(String message) {
        android.util.Log.e("WebRTC", message == null ? "" : message);
    }

    public static void e(Throwable error) {
        android.util.Log.e("WebRTC", error == null ? "" : error.toString(), error);
    }
}
