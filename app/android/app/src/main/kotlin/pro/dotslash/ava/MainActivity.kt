package pro.dotslash.ava

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity is required by local_auth for the biometric /
// device-credential prompt.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
