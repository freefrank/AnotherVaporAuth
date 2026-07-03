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

    /// The home-screen icon follows the skin by enabling exactly one
    /// launcher activity-alias. DONT_KILL_APP keeps the app alive during
    /// the toggle; launchers pick the change up within a few seconds.
    private fun setLauncherIcon(skin: String) {
        val aliases = mapOf(
            "pro.dotslash.ava.LauncherNeon" to (skin != "pixel"),
            "pro.dotslash.ava.LauncherPixel" to (skin == "pixel"),
        )
        for ((name, enabled) in aliases) {
            packageManager.setComponentEnabledSetting(
                ComponentName(this, name),
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
