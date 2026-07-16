package pro.dotslash.ava.play

import android.app.Activity
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

/**
 * UMP consent flow: `consent.ensure` → Boolean (canRequestAds).
 *
 * requestConsentInfoUpdate + loadAndShowConsentFormIfRequired on the
 * Activity. Cached consent from a previous session is honored when the
 * network update fails, so a temporarily-offline user who already consented
 * still gets ads instead of an error.
 */
class ConsentHandler {
    /** `consent.privacyOptionsRequired` → Boolean: whether UMP wants us to
     * expose a re-open entry (GDPR regions after a consent choice). */
    fun privacyOptionsRequired(activity: Activity, result: GuardedResult) {
        val info = UserMessagingPlatform.getConsentInformation(activity)
        result.success(
            info.privacyOptionsRequirementStatus ==
                ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED,
        )
    }

    /** `consent.privacyOptions` → Boolean(true): shows the UMP privacy
     * options form so the user can change an earlier consent choice. */
    fun showPrivacyOptions(activity: Activity, result: GuardedResult) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { formError ->
            if (formError != null) {
                result.error(
                    "consent_failed",
                    "privacyOptions: ${formError.errorCode} ${formError.message}",
                )
            } else {
                result.success(true)
            }
        }
    }

    fun ensure(activity: Activity, result: GuardedResult) {
        val info = UserMessagingPlatform.getConsentInformation(activity)
        val params = ConsentRequestParameters.Builder().build()
        info.requestConsentInfoUpdate(
            activity,
            params,
            {
                // Update OK — show the form if (and only if) it is required.
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { formError ->
                    if (formError != null && !info.canRequestAds()) {
                        result.error(
                            "consent_failed",
                            "form: ${formError.errorCode} ${formError.message}",
                        )
                    } else {
                        result.success(info.canRequestAds())
                    }
                }
            },
            { updateError ->
                if (info.canRequestAds()) {
                    // Stale-but-valid consent from a previous session.
                    result.success(true)
                } else {
                    result.error(
                        "consent_failed",
                        "update: ${updateError.errorCode} ${updateError.message}",
                    )
                }
            },
        )
    }
}
