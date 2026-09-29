package org.telegram.messenger;

import android.os.Handler;
import android.os.Looper;

/**
 * Compile-time shim for Telegram's AndroidUtilities, referenced by the vendored
 * org.webrtc TextureViewRenderer (UI-thread posting of render updates).
 */
public final class AndroidUtilities {
    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());

    private AndroidUtilities() {}

    public static void runOnUIThread(Runnable runnable) {
        MAIN_HANDLER.post(runnable);
    }

    public static void cancelRunOnUIThread(Runnable runnable) {
        MAIN_HANDLER.removeCallbacks(runnable);
    }
}
