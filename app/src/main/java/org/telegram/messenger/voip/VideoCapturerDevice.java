package org.telegram.messenger.voip;

import android.media.projection.MediaProjection;

/**
 * Stand-in for Telegram's VideoCapturerDevice.
 *
 * This is not an optional compile-time stub. The native AndroidContext constructor looks the
 * class up by name and then does:
 *
 *     jmethodID initMethodId = env->GetMethodID(VideoCapturerDeviceClass, "<init>", "(Z)V");
 *     javaCapturer = env->NewObject(VideoCapturerDeviceClass, initMethodId, screencast);
 *
 * GetMethodID returns null when no (Z)V constructor exists, and NewObject with a null method id
 * aborts the process - that was the "signal 6" on every call, raised before tgcalls did any
 * real work. The destructor calls onDestroy() the same way, so that has to exist too.
 *
 * The capturer itself is never used in Schatz: it exists for the outgoing video track, and
 * Schatz is audio only. getMediaProjection() still has to exist because the vendored
 * org.webrtc voiceengine WebRtcAudioRecord calls it for screen-share capture.
 */
public final class VideoCapturerDevice {
    public VideoCapturerDevice(boolean screencast) {
    }

    /** Called by the native AndroidContext destructor. Nothing here owns a platform resource. */
    public void onDestroy() {
    }

    public static MediaProjection getMediaProjection() {
        return null;
    }
}
