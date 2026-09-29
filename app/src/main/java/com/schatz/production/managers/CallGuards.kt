package com.schatz.production.managers

/**
 * The rules that decide whether a user action on a call may be forwarded to TDLib, kept free of
 * Android and TDLib types so they can be regression tested on the JVM.
 *
 * The bug this exists for: one tap on the incoming notification fired two AcceptCall requests for
 * the same call - the shade action, and then the Answer button on the call screen the full-screen
 * intent had opened. TDLib accepted the first and rejected the second as "call not found", which
 * on the TDLib build this app ships ends in a native abort, taking the app down mid-call.
 */
object CallGuards {

    enum class Decision {
        /** Forward the request to TDLib. */
        ALLOW,

        /** Drop it locally; TDLib must not hear about it. */
        IGNORE
    }

    /**
     * An accept is only meaningful for a call that is currently ringing, that TDLib is still
     * telling us about, and that this call id has not already accepted.
     */
    fun canAnswer(
        currentCallId: Int,
        requestedCallId: Int,
        answeredCallId: Int,
        state: CallState,
    ): Decision {
        if (requestedCallId == 0) return Decision.IGNORE
        // A tap naming a call TDLib is no longer reporting: an old notification.
        if (requestedCallId != currentCallId) return Decision.IGNORE
        // Already answered, even if the state has since flapped back to ringing.
        if (requestedCallId == answeredCallId) return Decision.IGNORE
        // Answering is only possible while the call is actually ringing.
        if (state != CallState.INCOMING && state != CallState.RINGING) return Decision.IGNORE
        return Decision.ALLOW
    }

    /**
     * Declining and ending stay legal through the whole live portion of a call, including the
     * media handshake - if tgcalls never establishes, they are the only way out. Only calls that
     * are not live, or that TDLib is no longer reporting, are refused.
     */
    fun canDiscard(
        currentCallId: Int,
        requestedCallId: Int,
        state: CallState,
    ): Decision {
        if (requestedCallId == 0) return Decision.IGNORE
        if (requestedCallId != currentCallId) return Decision.IGNORE
        if (!state.isLive()) return Decision.IGNORE
        return Decision.ALLOW
    }
}
