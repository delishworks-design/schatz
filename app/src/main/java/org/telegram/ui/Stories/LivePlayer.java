package org.telegram.ui.Stories;

/**
 * Compile-time shim for Telegram's LivePlayer, referenced by the vendored
 * org.webrtc Camera1Session/Camera2Session: a non-null recording marker forces
 * camera rotation to 0. Schatz never records, so this stays null and the
 * orientation helper path runs as usual.
 */
public final class LivePlayer {
    public static Object recording = null;

    private LivePlayer() {}
}
