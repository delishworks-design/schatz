package org.telegram.messenger.voip;

import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;

/**
 * Compile-time shim for Telegram's VoIPService, referenced only for its nested
 * ProxyVideoSink type by the vendored org.webrtc TextureViewRenderer. Schatz never
 * installs a ProxyVideoSink, so the instanceof branch is never taken; the class
 * exists purely so the vendored sources compile and link.
 */
public final class VoIPService {
    private VoIPService() {}

    public static final class ProxyVideoSink implements VideoSink {
        public void addTarget(VideoSink target) {}

        public void removeTarget(VideoSink target) {}

        public void addBackground(VideoSink background) {}

        public void removeBackground(VideoSink background) {}

        @Override
        public void onFrame(VideoFrame frame) {}
    }
}
