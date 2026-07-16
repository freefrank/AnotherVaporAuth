package pro.dotslash.ava.play

import android.app.Activity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.ads.AdSize
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Entry point of the play-channel native layer.
 *
 * Discovered from MainActivity (src/main) purely by reflection — nothing in
 * src/main imports this package, so the cn flavor compiles and runs without
 * any Google class in the APK.
 *
 * Registers:
 * - MethodChannel "ava/play": consent.ensure / signin.idToken /
 *   billing.subscribe / billing.restore / rewarded.show / banner.height
 * - PlatformViewFactory "ava/banner" (+ "ava/banner_events" for load events)
 */
object PlayChannel {
    @JvmStatic
    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val appContext = activity.applicationContext

        val bannerEvents = MethodChannel(messenger, "ava/banner_events")
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "ava/banner",
            BannerViewFactory(bannerEvents),
        )

        val consent = ConsentHandler()
        val signIn = SignInHandler()
        val billing = BillingHandler(appContext)
        val rewarded = RewardedHandler(appContext)

        MethodChannel(messenger, "ava/play").setMethodCallHandler { call, rawResult ->
            val result = GuardedResult(rawResult)
            when (call.method) {
                "consent.ensure" ->
                    consent.ensure(activity, result)

                "consent.privacyOptionsRequired" ->
                    consent.privacyOptionsRequired(activity, result)

                "consent.privacyOptions" ->
                    consent.showPrivacyOptions(activity, result)

                "signin.idToken" ->
                    signIn.idToken(activity, call.argument<String>("serverClientId"), result)

                "billing.subscribe" -> {
                    val productId = call.argument<String>("productId")
                    if (productId.isNullOrBlank()) {
                        result.error("billing_error", "productId missing")
                    } else {
                        billing.subscribe(activity, productId, result)
                    }
                }

                "billing.restore" ->
                    billing.restore(result)

                "rewarded.show" -> {
                    val adUnitId = call.argument<String>("adUnitId")
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    if (adUnitId.isNullOrBlank()) {
                        result.error("ad_load_failed", "adUnitId missing")
                    } else {
                        rewarded.show(activity, adUnitId, deviceId, result)
                    }
                }

                "banner.height" -> {
                    val widthDp = call.argument<Int>("widthDp")
                    if (widthDp == null || widthDp <= 0) {
                        result.error("bad_args", "widthDp missing or invalid")
                    } else {
                        result.success(
                            AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
                                appContext,
                                widthDp,
                            ).height,
                        )
                    }
                }

                else -> rawResult.notImplemented()
            }
        }

        // FlutterFragmentActivity is a LifecycleOwner; release the billing
        // service connection when the Activity goes away.
        (activity as? LifecycleOwner)?.lifecycle?.addObserver(
            object : DefaultLifecycleObserver {
                override fun onDestroy(owner: LifecycleOwner) {
                    billing.destroy()
                }
            },
        )
    }
}
