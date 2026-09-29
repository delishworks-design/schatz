package com.schatz.production

import com.schatz.production.managers.CallGuards
import com.schatz.production.managers.CallGuards.Decision
import com.schatz.production.managers.CallState
import com.schatz.production.managers.isLive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for the call-action guards.
 *
 * The crash: one tap on the incoming notification produced two AcceptCall requests for the same
 * call - the shade action, then the Answer button on the call screen the full-screen intent had
 * already opened. TDLib accepted the first and answered the second with "call not found", and on
 * this TDLib build that path ends in a native abort that takes the process down mid-call. The
 * guards below are what stop the second request from ever leaving the app.
 */
class CallGuardsTest {

    private val callId = 3

    @Test
    fun `a ringing call can be answered`() {
        assertEquals(
            Decision.ALLOW,
            CallGuards.canAnswer(currentCallId = callId, requestedCallId = callId, answeredCallId = 0, state = CallState.RINGING)
        )
    }

    @Test
    fun `incoming is also answerable`() {
        assertEquals(
            Decision.ALLOW,
            CallGuards.canAnswer(currentCallId = callId, requestedCallId = callId, answeredCallId = 0, state = CallState.INCOMING)
        )
    }

    /** The exact crash: the first accept moves the state, so the second must be dropped. */
    @Test
    fun `a second answer for the same call is refused`() {
        assertEquals(
            Decision.IGNORE,
            // answeredCallId is set by the first accept; state is CONNECTING.
            CallGuards.canAnswer(currentCallId = callId, requestedCallId = callId, answeredCallId = callId, state = CallState.CONNECTING)
        )
    }

    /**
     * The id backstop matters on its own: TDLib re-sends UpdateCall, so the state can be back to
     * RINGING by the time the duplicate tap arrives.
     */
    @Test
    fun `an already answered call is refused even if the state flapped back to ringing`() {
        assertEquals(
            Decision.IGNORE,
            CallGuards.canAnswer(currentCallId = callId, requestedCallId = callId, answeredCallId = callId, state = CallState.RINGING)
        )
    }

    @Test
    fun `answering a call TDLib no longer reports is refused`() {
        assertEquals(
            Decision.IGNORE,
            CallGuards.canAnswer(currentCallId = callId, requestedCallId = 7, answeredCallId = 0, state = CallState.RINGING)
        )
    }

    @Test
    fun `answering with no call id is refused`() {
        assertEquals(
            Decision.IGNORE,
            CallGuards.canAnswer(currentCallId = 0, requestedCallId = 0, answeredCallId = 0, state = CallState.RINGING)
        )
    }

    @Test
    fun `answering an outgoing call is refused`() {
        listOf(CallState.CALLING, CallState.CONNECTING, CallState.MEDIA_CONNECTING, CallState.CONNECTED).forEach { state ->
            assertEquals(
                "answering must be refused in $state",
                Decision.IGNORE,
                CallGuards.canAnswer(currentCallId = callId, requestedCallId = callId, answeredCallId = 0, state = state)
            )
        }
    }

    @Test
    fun `answering a terminal call is refused`() {
        listOf(CallState.ENDED, CallState.DECLINED, CallState.MISSED, CallState.FAILED, CallState.BUSY, CallState.IDLE)
            .forEach { state ->
                assertEquals(
                    "answering must be refused in $state",
                    Decision.IGNORE,
                    CallGuards.canAnswer(currentCallId = callId, requestedCallId = callId, answeredCallId = 0, state = state)
                )
            }
    }

    /** Declining and ending must stay usable for the whole live call, media handshake included. */
    @Test
    fun `discard is allowed through the whole live call`() {
        listOf(
            CallState.CALLING, CallState.RINGING, CallState.INCOMING, CallState.CONNECTING,
            CallState.MEDIA_CONNECTING, CallState.CONNECTED
        ).forEach { state ->
            assertEquals(
                "discard must be allowed in $state",
                Decision.ALLOW,
                CallGuards.canDiscard(currentCallId = callId, requestedCallId = callId, state = state)
            )
        }
    }

    @Test
    fun `discard is refused when no call is live`() {
        listOf(CallState.IDLE, CallState.ENDED, CallState.DECLINED, CallState.MISSED, CallState.FAILED, CallState.BUSY)
            .forEach { state ->
                assertEquals(
                    "discard must be refused in $state",
                    Decision.IGNORE,
                    CallGuards.canDiscard(currentCallId = callId, requestedCallId = callId, state = state)
                )
            }
    }

    /** A stale notification tap must not discard the call the user is currently on. */
    @Test
    fun `discard is refused for a call TDLib no longer reports`() {
        assertEquals(
            Decision.IGNORE,
            CallGuards.canDiscard(currentCallId = callId, requestedCallId = 7, state = CallState.CONNECTED)
        )
    }

    @Test
    fun `discard is refused with no call id`() {
        assertEquals(
            Decision.IGNORE,
            CallGuards.canDiscard(currentCallId = 0, requestedCallId = 0, state = CallState.CONNECTED)
        )
    }

    @Test
    fun `live covers every non terminal state the call passes through`() {
        assertTrue(CallState.RINGING.isLive())
        assertTrue(CallState.CONNECTING.isLive())
        assertTrue(CallState.MEDIA_CONNECTING.isLive())
        assertTrue(CallState.CONNECTED.isLive())
        assertFalse(CallState.IDLE.isLive())
        assertFalse(CallState.ENDED.isLive())
        assertFalse(CallState.FAILED.isLive())
    }
}
