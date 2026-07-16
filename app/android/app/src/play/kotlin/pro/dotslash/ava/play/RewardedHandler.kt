package pro.dotslash.ava.play

import android.app.Activity
import android.content.Context
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.gms.ads.rewarded.ServerSideVerificationOptions

/**
 * Rewarded ads: `rewarded.show` {adUnitId, deviceId} → Boolean (reward earned).
 *
 * Load → attach SSV options (userId = deviceId, so the reward callback can be
 * verified server-side per device) → show. True only if onUserEarnedReward
 * fired before dismissal; closing early returns false.
 */
class RewardedHandler(private val context: Context) {
    fun show(activity: Activity, adUnitId: String, deviceId: String, result: GuardedResult) {
        AdsInit.ensure(context)
        RewardedAd.load(
            context,
            adUnitId,
            AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    ad.setServerSideVerificationOptions(
                        ServerSideVerificationOptions.Builder()
                            .setUserId(deviceId)
                            .build(),
                    )
                    var earned = false
                    ad.fullScreenContentCallback = object : FullScreenContentCallback() {
                        override fun onAdDismissedFullScreenContent() {
                            result.success(earned)
                        }

                        override fun onAdFailedToShowFullScreenContent(error: AdError) {
                            // Same code as load failure: from Dart's point of
                            // view the ad never played.
                            result.error(
                                "ad_load_failed",
                                "show: ${error.code} ${error.message}",
                            )
                        }
                    }
                    ad.show(activity) { earned = true }
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    result.error("ad_load_failed", "${error.code} ${error.message}")
                }
            },
        )
    }
}
