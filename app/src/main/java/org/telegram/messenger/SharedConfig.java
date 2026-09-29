package org.telegram.messenger;

/**
 * Compile-time shim for Telegram's SharedConfig, referenced by the vendored
 * org.webrtc voiceengine classes (acoustic-echo/noise-suppressor effects flag).
 */
public final class SharedConfig {
    /** false = allow AEC/NS audio effects (same as Telegram's default). */
    public static boolean disableVoiceAudioEffects = false;

    private SharedConfig() {}
}
