package pro.dotslash.ava.play

import android.content.Context
import android.view.View
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * PlatformView "ava/banner": an adaptive AdMob banner.
 *
 * creationParams: {adUnitId: String, widthDp: Int}. Load state is reported to
 * Dart over the "ava/banner_events" channel as
 * invokeMethod("event", {"id": viewId, "loaded": true|false}).
 */
class BannerViewFactory(
    private val events: MethodChannel,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        return BannerPlatformView(context, viewId, params, events)
    }
}

private class BannerPlatformView(
    context: Context,
    viewId: Int,
    params: Map<String, Any?>,
    events: MethodChannel,
) : PlatformView {
    private val adView = AdView(context)

    init {
        AdsInit.ensure(context)
        val widthDp = (params["widthDp"] as? Number)?.toInt() ?: 320
        adView.adUnitId = params["adUnitId"] as? String ?: ""
        adView.setAdSize(
            AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(context, widthDp),
        )
        adView.adListener = object : AdListener() {
            // AdListener callbacks arrive on the main thread; invokeMethod is
            // safe to call directly.
            override fun onAdLoaded() {
                events.invokeMethod("event", mapOf("id" to viewId, "loaded" to true))
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                events.invokeMethod("event", mapOf("id" to viewId, "loaded" to false))
            }
        }
        adView.loadAd(AdRequest.Builder().build())
    }

    override fun getView(): View = adView

    override fun dispose() {
        adView.destroy()
    }
}
