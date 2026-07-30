import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../json_coerce.dart';
import '../models/steam_guard_account.dart';
import 'community_session.dart';

/// Why Steam refused a product key, derived from `purchase_result_details`.
///
/// The numbers are `EPurchaseResultDetail` (SteamKit's `SteamLanguage.cs`);
/// the subset named here is exactly the one Valve's own `registerkey.js` has
/// distinct copy for. Everything else stays [unknown] so the UI can show the
/// raw number instead of inventing a reason — guessing wrong is worse than
/// saying "Steam rejected it (code N)", because the user acts on the advice.
enum KeyRedeemError {
  /// `BadActivationCode` (14) — a typo, or not a Steam key at all.
  invalidKey,

  /// `AlreadyPurchased` (9) — this account already owns the product.
  alreadyOwned,

  /// `DuplicateActivationCode` (15) — already activated, here or elsewhere.
  alreadyActivated,

  /// `RestrictedCountry` (13) — not activatable in the account's country.
  regionLocked,

  /// `DoesNotOwnRequiredApp` (24) — DLC/expansion whose base product the
  /// account doesn't own.
  needsBaseProduct,

  /// `MustLoginPS3AppForPurchase` (36) — must be played on a PS3 first.
  needsPs3Login,

  /// `RateLimited` (53) — too many recent *failed* attempts; Steam blocks
  /// activations for roughly an hour.
  rateLimited,

  /// Steam refused it for a reason we don't have specific copy for; the UI
  /// shows [KeyRedeemResult.detail] verbatim.
  unknown,
}

/// Outcome of activating one product key.
class KeyRedeemResult {
  /// Steam accepted the key and the products are on the account now.
  final bool success;

  /// Raw `purchase_result_details` (0 on success). Kept even on success so the
  /// debug log and the unknown-error copy can quote Steam's own number.
  final int detail;

  /// Why it failed; null when [success].
  final KeyRedeemError? error;

  /// Names of the packages the key granted. May be empty even on success —
  /// Steam occasionally answers with a receipt that carries no line items.
  final List<String> products;

  const KeyRedeemResult({
    required this.success,
    required this.detail,
    this.error,
    this.products = const [],
  });

  /// Maps `purchase_result_details` to the reason enum. Static and pure so the
  /// mapping is unit-testable without a network stack.
  static KeyRedeemError errorFor(int detail) => switch (detail) {
        9 => KeyRedeemError.alreadyOwned,
        13 => KeyRedeemError.regionLocked,
        14 => KeyRedeemError.invalidKey,
        15 => KeyRedeemError.alreadyActivated,
        24 => KeyRedeemError.needsBaseProduct,
        36 => KeyRedeemError.needsPs3Login,
        53 => KeyRedeemError.rateLimited,
        _ => KeyRedeemError.unknown,
      };

  /// Parses an `/account/ajaxregisterkey/` reply.
  ///
  /// Success is `success == 1`, which is exactly what Valve's own
  /// `registerkey.js` branches on: it renders the receipt when the flag is 1
  /// and only reads `purchase_result_details` on the failure branch. Requiring
  /// a zero detail *as well* would be stricter than Steam's own client and
  /// could report a key that really was activated as failed — sending the user
  /// to burn a second attempt on a key they now own.
  ///
  /// (This is not the `optional bool success` protobuf trap: that field is
  /// absent-by-default on the wire, whereas this is an explicit int the store's
  /// own front-end trusts.)
  ///
  /// The detail is read from `purchase_result_details`, falling back to the
  /// receipt's own copy. An empty/undecodable body — what the shared JSON
  /// decoder returns for a bodiless 200 — has no `success` at all and so falls
  /// through to a failure, which is right: there is no receipt to show, and
  /// claiming an activation that may not have happened is the worse error.
  static KeyRedeemResult parse(Map<String, dynamic> json) {
    final receipt = json['purchase_receipt_info'];
    final receiptMap = receipt is Map<String, dynamic> ? receipt : null;
    // `result_detail` is the protobuf spelling (CStore_PurchaseReceiptInfo
    // field 4); captures of the *web* reply show `resultdetail`. The store's
    // JSON layer and the protobuf don't agree on it and we can't test which
    // one production sends, so accept both rather than silently read -1.
    final detail = asIntOrNull(json['purchase_result_details']) ??
        asIntOrNull(receiptMap?['result_detail']) ??
        asIntOrNull(receiptMap?['resultdetail']) ??
        -1;
    if (asIntOrNull(json['success']) != 1) {
      return KeyRedeemResult(
        success: false,
        detail: detail,
        error: KeyRedeemResult.errorFor(detail),
      );
    }
    final items = receiptMap?['line_items'];
    final products = <String>[];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        // `line_item_description`: what registerkey.js reads, what the protobuf
        // calls field 3, and — confirmed on a live account 2026-07-29 — what
        // production actually sends. The `packageName` spelling from
        // third-party captures never matched and is no longer tried.
        final name = item['line_item_description'];
        if (name is String && name.trim().isNotEmpty) products.add(name.trim());
      }
    }
    return KeyRedeemResult(success: true, detail: detail, products: products);
  }
}

/// Activates Steam product keys (CD keys) on an account —
/// `store.steampowered.com/account/ajaxregisterkey/`.
///
/// This is the same endpoint the store's own "Activate a Product on Steam"
/// page posts to, and the request shape is taken from Valve's own
/// `store.steampowered.com/public/javascript/registerkey.js`. It authenticates
/// with the store cookie set ([storeCookies]) rather than an access token
/// query parameter.
///
/// The *nicer* path — `IStoreService/RegisterCDKey`
/// (`CStore_RegisterCDKey_Request`, what ArchiSteamFarm uses) — is deliberately
/// not used: it is a unified message reachable only over a CM connection, and
/// `GetSupportedAPIList` does not publish it on `api.steampowered.com` (see
/// steamapi.xpaw.me/IStoreService). AVA is a Web-API-only client, so the
/// store's own ajax endpoint is the only path available. If AVA ever grows a
/// CM transport, switch to the protobuf call — it is access-token
/// authenticated and has a typed response.
///
/// **Activation is irreversible** — a consumed key cannot be un-consumed, and
/// Steam blocks further attempts for about an hour after a handful of failed
/// ones. The UI must confirm before calling [redeem] and must not retry
/// automatically on a rejection.
class StoreKeyClient {
  final SteamApiClient api;
  StoreKeyClient(this.api);

  /// The form value Steam expects for [raw]: uppercased with all whitespace
  /// removed. Punctuation is left exactly as typed — key layouts vary
  /// (15-char triplets, 25-char quintuplets, and Valve's own dashless
  /// promo codes), so "helpfully" re-grouping the dashes would corrupt shapes
  /// we don't know about. Steam is the only authority on the format.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Activates [productKey] on [account].
  ///
  /// Throws [MissingAccessTokenException] when the session can't authenticate,
  /// and [CommunityAuthException] when the store bounces us to the login page
  /// (a stale cookie) — both mean "re-auth and try again", and both must be
  /// distinguished from a key Steam actually rejected.
  Future<KeyRedeemResult> redeem(
      SteamGuardAccount account, String productKey) async {
    requireAccessToken(account);
    final key = normalize(productKey);
    // Load the activation page first. This is not politeness — the store
    // Set-Cookies `steamCountry` / `browserid` on first contact and answers
    // with a 302 back to the same URL, so a POST sent straight at the ajax
    // endpoint never runs (observed 2026-07-28: `HTTP 302 →
    // .../ajaxregisterkey/`, its own URL, on a session that was otherwise
    // perfectly valid). The GET is safe to repeat and consumes nothing.
    final jar = await api.storeBootstrap(
      '/account/registerkey',
      storeCookies(account, sessionId: newCommunitySessionId()),
    );
    // Whatever `sessionid` the bootstrap ended up with — Steam's if it issued
    // one, ours otherwise — has to appear in the form body too.
    final sid = jar['sessionid'] ?? newCommunitySessionId();
    jar['sessionid'] = sid;
    final json = await api.storePostJson(
      '/account/ajaxregisterkey/',
      {'product_key': key, 'sessionid': sid},
      cookies: jar,
      referer: '${SteamApiClient.storeBase}/account/registerkey',
    );
    final result = KeyRedeemResult.parse(json);
    // The key itself is a credential — log the outcome, never the value.
    dlog('registerkey -> success=${result.success} detail=${result.detail} '
        'products=${result.products.length}');
    return result;
  }
}
