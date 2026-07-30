package pro.dotslash.ava

import android.os.Build
import android.view.RoundedCorner
import android.view.WindowInsets
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
    /// divides by devicePixelRatio). 0 when the platform can't tell us:
    /// `getRoundedCorner` is API 31+, and `rootWindowInsets` is null until the
    /// decor view is attached.
    ///
    /// Read fresh on every call rather than cached at startup — this app runs
    /// on a foldable, and folding swaps to a display with a different radius.
    private fun bottomCornerRadiusPx(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return 0
        val insets = window?.decorView?.rootWindowInsets ?: return 0
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
