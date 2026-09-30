package org.webrtc;

import com.schatz.production.managers.CrashReporter;

/**
 * Routes the vendored org.webrtc Java logging into the app's on-disk diagnostics trail.
 *
 * Everything in webrtc logs through {@link Logging}, which by default only reaches a logger the
 * device cannot show (and android.util.Log, which needs logcat). The call path runs native code
 * that aborts without warning, so when an audio or JNI step fails, that message is often the only
 * description of what went wrong. This keeps it in a file the app can show under Settings.
 *
 * Intentionally noisy-free: only WARNING and above is recorded, so the trail stays readable.
 */
public final class SchatzWebRtcLoggable implements Loggable {

    public SchatzWebRtcLoggable() {
    }

    public static void install() {
        Logging.injectLoggable(new SchatzWebRtcLoggable(), Logging.Severity.LS_WARNING);
    }

    @Override
    public void onLogMessage(String message, Logging.Severity severity, String tag) {
        if (severity.ordinal() < Logging.Severity.LS_WARNING.ordinal()) {
            return;
        }
        try {
            CrashReporter.note("webrtc/" + tag + ": " + message);
        } catch (Throwable ignored) {
            // Diagnostics must never be the thing that breaks a call.
        }
    }
}
