package pro.dotslash.ava

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth for the biometric /
// device-credential prompt.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ava/launcher_icon")
            .setMethodCallHandler { call, result ->
                if (call.method == "setIcon") {
                    setLauncherIcon(call.argument<String>("skin") ?: "default")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /// The home-screen icon follows the skin by enabling exactly one launcher
    /// activity-alias. Called only at startup and when the app goes to the
    /// background, so the swap is invisible and never disrupts the running
    /// task. DONT_KILL_APP keeps the process alive; each alias is written only
    /// when its state actually needs to change, so unchanged launches cause no
    /// launcher churn.
    private fun setLauncherIcon(skin: String) {
        // Manifest defaults: Neon enabled, Pixel disabled.
        val aliases = mapOf(
            "pro.dotslash.ava.LauncherNeon" to (skin != "pixel"),
            "pro.dotslash.ava.LauncherPixel" to (skin == "pixel"),
        )
        for ((name, enabled) in aliases) {
            val component = ComponentName(this, name)
            val target =
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            if (packageManager.getComponentEnabledSetting(component) == target) {
                continue // already correct — writing again would churn launchers
            }
            packageManager.setComponentEnabledSetting(
                component, target, PackageManager.DONT_KILL_APP,
            )
        }
    }
}
