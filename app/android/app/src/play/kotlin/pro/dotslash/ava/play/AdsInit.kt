package pro.dotslash.ava.play

import android.content.Context
import com.google.android.gms.ads.MobileAds
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Lazy one-shot initializer for the Google Mobile Ads SDK.
 *
 * MobileAds.initialize is expensive (loads the ads process / WebView bits),
 * so it runs only when an ads API is first actually used — banner view
 * creation or rewarded.show — and on a background thread, exactly once.
 */
internal object AdsInit {
    private val started = AtomicBoolean(false)

    fun ensure(context: Context) {
        if (started.compareAndSet(false, true)) {
            val app = context.applicationContext
            Thread({ MobileAds.initialize(app) }, "ava-ads-init").start()
        }
    }
}
