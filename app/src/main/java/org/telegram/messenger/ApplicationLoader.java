package org.telegram.messenger;

import android.content.Context;

/**
 * Compile-time shim for Telegram's ApplicationLoader (used by the vendored
 * org.webrtc OrientationHelper for the application context). Schatz sets
 * {@link #applicationContext} during TgCallsBridge initialization.
 */
public final class ApplicationLoader {
    public static Context applicationContext;

    private ApplicationLoader() {}
}
