package pro.dotslash.ava.play

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams

/**
 * Play Billing (subscriptions only).
 *
 * - `billing.subscribe` {productId} → purchaseToken (acknowledged first).
 * - `billing.restore` → latest valid subscription's purchaseToken, or null.
 *
 * Lifecycle: one BillingClient reused across calls; reconnects lazily when
 * the service drops; endConnection() from [destroy] on Activity destroy.
 * Only one subscribe flow may be in flight — a second concurrent call gets
 * error "busy" immediately (the global PurchasesUpdatedListener can only be
 * correlated with one pending result).
 */
class BillingHandler(private val context: Context) : PurchasesUpdatedListener {
    private val main = Handler(Looper.getMainLooper())
    private var client: BillingClient? = null

    /** The one in-flight subscribe result; PurchasesUpdatedListener resolves it. */
    private var pendingSubscribe: GuardedResult? = null

    // ---- connection -------------------------------------------------------

    private fun requireClient(): BillingClient {
        client?.let { return it }
        return BillingClient.newBuilder(context)
            .setListener(this)
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder().enableOneTimeProducts().build(),
            )
            .build()
            .also { client = it }
    }

    /** Runs [onReady] with a connected client, reusing an existing connection. */
    private fun ensureConnected(
        onError: (BillingResult) -> Unit,
        onReady: (BillingClient) -> Unit,
    ) {
        val c = requireClient()
        if (c.isReady) {
            onReady(c)
            return
        }
        c.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                main.post {
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        onReady(c)
                    } else {
                        onError(billingResult)
                    }
                }
            }

            override fun onBillingServiceDisconnected() {
                // Connection lost; next ensureConnected() reconnects lazily.
            }
        })
    }

    /** Call on Activity destroy: releases the service connection. */
    fun destroy() {
        pendingSubscribe?.error("billing_error", "activity destroyed")
        pendingSubscribe = null
        client?.endConnection()
        client = null
    }

    // ---- subscribe --------------------------------------------------------

    fun subscribe(activity: Activity, productId: String, result: GuardedResult) {
        if (pendingSubscribe != null) {
            result.error("busy", "another billing flow is already in progress")
            return
        }
        pendingSubscribe = result
        ensureConnected(onError = { br -> failPending(br) }) { c ->
            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(
                    listOf(
                        QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(productId)
                            .setProductType(BillingClient.ProductType.SUBS)
                            .build(),
                    ),
                )
                .build()
            c.queryProductDetailsAsync(params) { br, detailsResult ->
                main.post {
                    if (br.responseCode != BillingClient.BillingResponseCode.OK) {
                        failPending(br)
                        return@post
                    }
                    val details = detailsResult.productDetailsList
                        .firstOrNull { it.productId == productId }
                    if (details == null) {
                        clearPending()?.error(
                            "billing_error",
                            "product not found: $productId",
                        )
                        return@post
                    }
                    // Subscriptions must carry an offer token; take the first
                    // (base plan / default offer as configured in Play Console).
                    val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
                    if (offerToken == null) {
                        clearPending()?.error(
                            "billing_error",
                            "no subscription offer for: $productId",
                        )
                        return@post
                    }
                    val flowParams = BillingFlowParams.newBuilder()
                        .setProductDetailsParamsList(
                            listOf(
                                BillingFlowParams.ProductDetailsParams.newBuilder()
                                    .setProductDetails(details)
                                    .setOfferToken(offerToken)
                                    .build(),
                            ),
                        )
                        .build()
                    val launch = c.launchBillingFlow(activity, flowParams)
                    if (launch.responseCode != BillingClient.BillingResponseCode.OK) {
                        failPending(launch)
                    }
                    // Success path continues in onPurchasesUpdated.
                }
            }
        }
    }

    /** Global listener: resolves the pending subscribe result exactly once. */
    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
        main.post {
            if (pendingSubscribe == null) return@post // not our flow / already resolved
            if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                failPending(billingResult)
                return@post
            }
            val purchase = purchases.orEmpty()
                .firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED }
            if (purchase == null) {
                // e.g. slow-card PENDING purchase: no token to hand out yet.
                clearPending()?.error(
                    "billing_error",
                    "no PURCHASED purchase in update (pending payment?)",
                )
                return@post
            }
            acknowledgeThen(purchase) { ackResult ->
                if (ackResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    clearPending()?.success(purchase.purchaseToken)
                } else {
                    failPending(ackResult)
                }
            }
        }
    }

    /** Acknowledges [purchase] if needed, then invokes [done] on main. */
    private fun acknowledgeThen(purchase: Purchase, done: (BillingResult) -> Unit) {
        if (purchase.isAcknowledged) {
            done(BillingResult.newBuilder().setResponseCode(BillingClient.BillingResponseCode.OK).build())
            return
        }
        val c = client
        if (c == null || !c.isReady) {
            done(
                BillingResult.newBuilder()
                    .setResponseCode(BillingClient.BillingResponseCode.SERVICE_DISCONNECTED)
                    .build(),
            )
            return
        }
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        c.acknowledgePurchase(params) { br -> main.post { done(br) } }
    }

    private fun clearPending(): GuardedResult? {
        val p = pendingSubscribe
        pendingSubscribe = null
        return p
    }

    private fun failPending(br: BillingResult) {
        val pending = clearPending() ?: return
        when (br.responseCode) {
            BillingClient.BillingResponseCode.USER_CANCELED ->
                pending.error("canceled", br.debugMessage)
            BillingClient.BillingResponseCode.BILLING_UNAVAILABLE ->
                pending.error("billing_unavailable", br.debugMessage)
            // Multi-account: the Play Store's active account already holds the
            // subscription (typically after a restore the user gave up on).
            // Dedicated code so the UI can say "tap Restore", not "error 7".
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED ->
                pending.error("already_owned", br.debugMessage)
            else ->
                pending.error(
                    "billing_error",
                    "responseCode=${br.responseCode} ${br.debugMessage}",
                )
        }
    }

    // ---- restore ----------------------------------------------------------

    fun restore(result: GuardedResult) {
        ensureConnected(onError = { br -> restoreError(result, br) }) { c ->
            val params = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
            c.queryPurchasesAsync(params) { br, purchases ->
                main.post {
                    if (br.responseCode != BillingClient.BillingResponseCode.OK) {
                        restoreError(result, br)
                        return@post
                    }
                    val latest = purchases
                        .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                        .maxByOrNull { it.purchaseTime }
                    if (latest == null) {
                        result.success(null)
                        return@post
                    }
                    acknowledgeThen(latest) { ackResult ->
                        if (ackResult.responseCode == BillingClient.BillingResponseCode.OK) {
                            result.success(latest.purchaseToken)
                        } else {
                            restoreError(result, ackResult)
                        }
                    }
                }
            }
        }
    }

    private fun restoreError(result: GuardedResult, br: BillingResult) {
        when (br.responseCode) {
            BillingClient.BillingResponseCode.BILLING_UNAVAILABLE ->
                result.error("billing_unavailable", br.debugMessage)
            else ->
                result.error(
                    "billing_error",
                    "responseCode=${br.responseCode} ${br.debugMessage}",
                )
        }
    }
}
