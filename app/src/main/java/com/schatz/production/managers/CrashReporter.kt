package com.schatz.production.managers

import android.content.Context
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Persists a crash report to disk so it survives the process death.
 *
 * The call path runs native code (tgcalls/WebRTC), and a SIGSEGV there never reaches a Java
 * exception handler, so logcat was the only other place to look - which is not available on the
 * target device. Writing the report to a file makes the next launch show what actually died.
 */
object CrashReporter {

    private const val TAG = "SchatzCrash"
    private const val MAX_REPORTS = 5

    /** Short notes written as the call proceeds, so the report says how far it got. */
    private val breadcrumbs = ArrayList<String>()

    @Volatile private var appContext: Context? = null

    fun install(context: Context) {
        appContext = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                writeReport(thread.name, throwable)
            } catch (t: Throwable) {
                Log.e(TAG, "could not write crash report", t)
            }
            // Always hand back to the platform handler so the process still dies as expected.
            previous?.uncaughtException(thread, throwable)
        }
    }

    /** Records a short marker (max 20 kept) that lands in the next crash report. */
    fun note(message: String) {
        synchronized(breadcrumbs) {
            breadcrumbs.add("${System.currentTimeMillis()} $message")
            while (breadcrumbs.size > 20) breadcrumbs.removeAt(0)
        }
    }

    fun latestReport(): String? {
        val ctx = appContext ?: return null
        // A SIGSEGV in tgcalls is written by the native signal handler; a Java crash by the
        // uncaught exception handler. The native one is the interesting one when the app dies
        // the moment a call is answered, so show it first.
        val native = File(ctx.cacheDir, "native_crash.txt")
        if (native.exists()) {
            val text = runCatching { native.readText() }.getOrNull()
            if (!text.isNullOrBlank()) {
                return "NATIVE CRASH (tgcalls)\n\n$text\n\n${javaCrash().orEmpty()}"
            }
        }
        return javaCrash()
    }

    private fun javaCrash(): String? {
        val ctx = appContext ?: return null
        val file = File(ctx.cacheDir, FILE_NAME)
        if (!file.exists()) return null
        return runCatching { file.readText() }.getOrNull()
    }

    fun clear() {
        val ctx = appContext ?: return
        File(ctx.cacheDir, FILE_NAME).delete()
        File(ctx.cacheDir, "native_crash.txt").delete()
    }

    private fun writeReport(threadName: String, throwable: Throwable) {
        val ctx = appContext ?: return
        val stack = StringWriter().also { throwable.printStackTrace(PrintWriter(it)) }.toString()
        val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val trail = synchronized(breadcrumbs) { breadcrumbs.joinToString("\n") }
        val report = buildString {
            append("Schatz crash report\n")
            append("time: $stamp\n")
            append("thread: $threadName\n\n")
            append("last events:\n")
            append(if (trail.isBlank()) "  (none)\n" else trail.split("\n").joinToString("\n") { "  $it\n" })
            append("\nstack trace:\n$stack")
        }
        runCatching {
            val dir = File(ctx.cacheDir, "crashes").apply { mkdirs() }
            val stamped = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
            File(dir, "crash-$stamped.txt").writeText(report)
            // Keep the newest few, and mirror the latest so Settings can read it in one call.
            File(ctx.cacheDir, FILE_NAME).writeText(report)
            dir.listFiles()?.sortedBy { it.name }?.dropLast(MAX_REPORTS)?.forEach { it.delete() }
        }
    }

    private const val FILE_NAME = "last_crash.txt"
}
