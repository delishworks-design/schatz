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
        // Rehydrate the trail from the previous run. A native abort ends the process without
        // running any cleanup, so the markers that explain the crash are only on disk.
        synchronized(breadcrumbs) {
            breadcrumbs.clear()
            runCatching {
                File(appContext!!.cacheDir, TRAIL_FILE).readLines()
                    .filter { it.isNotBlank() }
                    .takeLast(40)
                    .forEach { breadcrumbs.add(it) }
            }
        }
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

    /**
     * Records a short marker that lands in the crash report and in the copyable bundle.
     *
     * Written to disk on every call, not just held in memory. A SIGABRT inside tgcalls kills the
     * process immediately, so an in-memory trail would be gone by the time the user came back to
     * read it - which is precisely the case this has to capture.
     */
    fun note(message: String) {
        val line = "${System.currentTimeMillis()} $message"
        synchronized(breadcrumbs) {
            breadcrumbs.add(line)
            // Generous enough to hold a whole session (startup, then a full call lifecycle) - the
            // trail is the only record of how far a call got, so it must not roll over too early.
            while (breadcrumbs.size > 40) breadcrumbs.removeAt(0)
        }
        val ctx = appContext ?: return
        runCatching {
            File(ctx.cacheDir, TRAIL_FILE).appendText(line + "\n")
        }
    }

    /**
     * The markers recorded so far, newest last. Read on demand rather than only at crash time: a
     * call that connects but carries no audio never crashes, and this trail is the only record of
     * how far it got.
     */
    fun breadcrumbsSnapshot(): String = synchronized(breadcrumbs) {
        if (breadcrumbs.isEmpty()) "(none recorded)" else breadcrumbs.joinToString("\n")
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

    /**
     * When the native handler last recorded a fault, or null if there is none. The file survives
     * until it is cleared, so without this a crash from an earlier run reads exactly like one that
     * just happened.
     */
    fun nativeCrashAgeMillis(): Long? {
        val ctx = appContext ?: return null
        val file = File(ctx.cacheDir, "native_crash.txt")
        if (!file.exists()) return null
        return runCatching { System.currentTimeMillis() - file.lastModified() }.getOrNull()
    }

    private fun javaCrash(): String? {
        val ctx = appContext ?: return null
        val file = File(ctx.cacheDir, FILE_NAME)
        if (!file.exists()) return null
        return runCatching { file.readText() }.getOrNull()
    }

    /**
     * Steps the native engine recorded while building a call instance. makeNativeInstance aborts
     * inside tgcalls and there is no backtrace on Android, so the last marker written is the only
     * evidence of how far it got.
     */
    fun nativeTrace(): String? {
        val ctx = appContext ?: return null
        val file = File(ctx.cacheDir, "native_trace.txt")
        if (!file.exists()) return null
        val lines = runCatching { file.readLines() }.getOrNull() ?: return null
        val last = lines.takeLast(14)
        return if (last.isEmpty()) null else last.joinToString("\n")
    }

    fun clear() {
        val ctx = appContext ?: return
        synchronized(breadcrumbs) { breadcrumbs.clear() }
        File(ctx.cacheDir, FILE_NAME).delete()
        File(ctx.cacheDir, TRAIL_FILE).delete()
        File(ctx.cacheDir, "native_crash.txt").delete()
        File(ctx.cacheDir, "native_trace.txt").delete()
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

    /** On-disk call trail. Survives the process death that a native abort causes. */
    private const val TRAIL_FILE = "call_trail.txt"
}
