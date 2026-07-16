package pro.dotslash.ava.play

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Exactly-once, main-thread wrapper around a [MethodChannel.Result].
 *
 * Billing / UMP / ads callbacks fire from arbitrary threads and are prone to
 * double-invocation patterns (e.g. PurchasesUpdatedListener firing after a
 * launchBillingFlow error was already reported). Every reply funnels through
 * here: the first success/error wins, later ones are silently dropped, and
 * the underlying result is always invoked on the main thread.
 */
class GuardedResult(private val result: MethodChannel.Result) {
    private val done = AtomicBoolean(false)
    private val main = Handler(Looper.getMainLooper())

    fun success(value: Any?) {
        if (done.compareAndSet(false, true)) {
            main.post { result.success(value) }
        }
    }

    fun error(code: String, message: String? = null, details: Any? = null) {
        if (done.compareAndSet(false, true)) {
            main.post { result.error(code, message, details) }
        }
    }

    /** True once a reply has been (or is being) delivered. */
    val isDone: Boolean get() = done.get()
}
