package pro.dotslash.ava

import android.os.Build
import android.view.RoundedCorner
import android.view.WindowInsets
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth for the biometric /
// device-credential prompt.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The display's rounded-corner radius. Flutter has no equivalent:
        // MediaQuery's padding / viewPadding / systemGestureInsets cover the
        // system bars and the display cutout, never the corner arc — so on a
        // modern phone the bottom row of any edge-to-edge screen gets clipped
        // by the physical corner. Pure AOSP API, so the cn flavor stays free
        // of Google classes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ava/display")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bottomCornerRadius" -> result.success(bottomCornerRadiusPx())
                    else -> result.notImplemented()
                }
            }
        // FLAG_SECURE, driven by the opt-in "block screenshots" setting.
        // Off by default: it also blacks out the window for legitimate
        // screen sharing and for the screenshots users attach to feedback,
        // so it is the user's call, not ours. Pure AOSP API.
        //
        // The flag lives on the window and resets when the activity is
        // recreated; Dart re-applies it on startup. The brief gap before
        // that exposes nothing — the vault is locked at launch, so the
        // first frames are the unlock screen, never a code.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ava/screen_security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val on = call.argument<Boolean>("enabled") ?: false
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Play-channel native services (UMP consent, Google sign-in, Play
        // Billing, AdMob) live entirely in the `play` flavor sourceset
        // (src/play/kotlin/pro/dotslash/ava/play/). Probe by reflection so
        // src/main never references a single Google class: on the cn flavor
        // the class simply doesn't exist and the probe is a silent no-op.
        // This is the ONLY reflection hook — everything else stays in play/.
        try {
            Class.forName("pro.dotslash.ava.play.PlayChannel")
                .getMethod(
                    "register",
                    FlutterEngine::class.java,
                    android.app.Activity::class.java,
                )
                .invoke(null, flutterEngine, this)
        } catch (_: ClassNotFoundException) {
            // cn flavor: expected — no play classes in this APK by design.
        }
    }

    /// The larger of the two bottom corner radii, in **physical pixels** (Dart
    /// divides by devicePixelRatio).
    ///
    ///  - `-1` — ask again later. `rootWindowInsets` is null until the decor
    ///    view is attached to the window, and Dart's first query happens
    ///    during the very first build, well before that. Returning 0 here made
    ///    "not ready yet" indistinguishable from "this display is square", and
    ///    Dart cached the 0 forever because nothing afterwards changed the
    ///    metrics. That is the bug this value exists to fix.
    ///  - `0` — API < 31, or a display with no rounded corners.
    ///  - `> 0` — the radius.
    ///
    /// Read fresh on every call rather than cached at startup: this app runs
    /// on a foldable, and folding swaps to a display with a different radius.
    private fun bottomCornerRadiusPx(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return 0
        val insets = window?.decorView?.rootWindowInsets ?: return -1
        return radiusOf(insets)
    }

    /// Split out so the API-31-only [RoundedCorner] reference sits in a method
    /// the older runtimes never verify.
    private fun radiusOf(insets: WindowInsets): Int {
        val left = insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_LEFT)?.radius ?: 0
        val right = insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_RIGHT)?.radius ?: 0
        return maxOf(left, right)
    }
}
