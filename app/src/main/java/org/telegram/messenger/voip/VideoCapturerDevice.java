package org.telegram.messenger.voip;

import android.media.projection.MediaProjection;

/**
 * Compile-time shim for Telegram's VideoCapturerDevice, referenced by the vendored
 * org.webrtc voiceengine WebRtcAudioRecord for screen-share microphone capture
 * (captureType == 1). Schatz does not use screen capture; returning null follows
 * the vendored code's own null-handling path.
 */
public final class VideoCapturerDevice {
    private VideoCapturerDevice() {}

    public static MediaProjection getMediaProjection() {
        return null;
    }
}
