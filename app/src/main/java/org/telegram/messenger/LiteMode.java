package org.telegram.messenger;

/**
 * Compile-time shim for Telegram's LiteMode, referenced by the vendored
 * org.webrtc TextureViewRenderer (call-animation feature flag). Schatz keeps
 * call animations enabled.
 */
public final class LiteMode {
    public static final long FLAG_CALLS_ANIMATIONS = 1L;

    private LiteMode() {}

    public static boolean isEnabled(long flag) {
        return true;
    }
}
