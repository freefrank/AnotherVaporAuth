# Inventory & Market — Design Spec

**Date:** 2026-07-01 · **Status:** approved, protocol verified live against Steam

Browse a Steam account's inventory (game picker like the Steam client) and list
items on the Community Market (price with live fees → list → mobile confirm),
plus a "My listings" view to see/cancel active listings.

## Scope (MVP)

- **Inventory browse**: game selector (any game the account has items in) + item grid.
- **Sell**: pick an item → sell sheet (market price reference + linked
  you-receive / buyer-pays fields with live fees) → list → mobile confirmation
  (reuse existing flow; respect the "auto-confirm market" setting).
- **My listings**: list active listings, cancel them.

Out of scope: buy orders, price history charts, multi-currency conversion beyond
the account's wallet currency.

## Verified protocol (checked live in a logged-in browser, 2026-07-01)

All community requests carry cookies `steamLoginSecure=<steamid>||<accessToken>`,
`mobileClient=android`, and a generated `sessionid` (also sent as a form param on
writes). Reads are GET; **market writes are POST form bodies**.

### 1. Games list + wallet info
`GET https://steamcommunity.com/profiles/<steamid>/inventory/` (HTML). Parse two
JS globals from the page:
- `g_rgAppContextData` = `{ "<appid>": { name, icon (full URL),
  rgContexts: { "<contextid>": { name, asset_count } } } }` → the game picker
  (one entry per app+context with `asset_count > 0`).
- `g_rgWalletInfo` = the **live** fee constants: `wallet_currency`,
  `wallet_fee_percent` (0.05), `wallet_publisher_fee_percent_default` (0.10),
  `wallet_market_minimum`, `wallet_currency_increment`, `wallet_fee_base`.
  Parse and cache per account so fee changes / different currencies are picked up
  automatically.

### 2. Inventory items
`GET /inventory/<steamid>/<appid>/<contextid>?l=english&count=75[&start_assetid=<last>]`
→ `{ assets:[{appid,contextid,assetid,classid,instanceid,amount}],
descriptions:[{classid,instanceid,market_hash_name,market_name,name,type,
marketable(0/1),tradable(0/1),commodity,icon_url,market_fee_app,...}], more_items,
last_assetid, total_inventory_count, success }`. Merge assets↔descriptions by
`"<classid>_<instanceid>"`. Only `marketable==1` items can be listed. Icon full
URL: `https://community.fastly.steamstatic.com/economy/image/<icon_url>`.
Paginate with `last_assetid` while `more_items`.

### 3. Market price (reference)
`GET /market/priceoverview/?appid=<appid>&currency=<wallet_currency>&market_hash_name=<name>`
→ `{ success, lowest_price, median_price, volume }` (localized strings). Rate
limited (~20/min); on failure show "price unavailable" and still allow manual pricing.

### 4. Fees (exact Steam algorithm, verified 9/9 samples)
Constants from `g_rgWalletInfo`; publisher pct from the item's `market_fee` if
present else `wallet_publisher_fee_percent_default`.
```
ToValidMarketPrice(p) = p <= market_minimum ? market_minimum
                      : p <= increment      ? increment
                      : round(p/increment)*increment   // increment>1
                      : p
CalculateFee(amt, pct) = pct > 0 ? ToValidMarketPrice(floor(amt*pct)) : 0
buyerPays(receive)     = ToValidMarketPrice(receive)
                       + CalculateFee(receive, publisherPct)
                       + CalculateFee(receive, steamPct)
receiveFromTotal(total)= iterative inverse (initial guess floor(total/(1+p+s)),
                         adjust by increment up to 3x, floor at market_minimum)
```
Ground truth (CNY, 5%/10%, min 7): 100→117, 7→21, 10→24, 233→267, 12345→14196.

### 5. List an item (sell)
`POST https://steamcommunity.com/market/sellitem/` form:
`{ sessionid, appid, contextid, assetid, amount, price }` where **`price` = the
amount the seller receives, in the wallet's minor units (cents)**. **Required
header `Referer: https://steamcommunity.com/profiles/<steamid>/inventory`** (else
HTTP 400). Response `{ success, requires_confirmation, needs_mobile_confirmation,
... }`. On `requires_confirmation` → run the existing mobile-confirmation flow.

### 6. My listings / cancel
`GET /market/mylistings/?norender=1&count=<n>&start=<n>` →
`{ success, num_active_listings, listings:[{ listingid, time_created,
asset:{appid,contextid,id,classid,instanceid,market_hash_name,name,icon_url,...},
price(buyer pays), fee, steam_fee, publisher_fee, currencyid, active }],
listings_to_confirm, buy_orders }`.
Cancel: `POST /market/removelisting/<listingid>` form `{ sessionid }` (Referer =
`/market/`). (Cancelling does not need a mobile confirmation.)

## Modules

- `core/models/steam_item.dart` — `InventoryGame`, `InventoryItem`, `MarketListing`,
  `WalletInfo`, `MarketPrice`.
- `core/market_fees.dart` — pure port of the algorithm above (`buyerPays`,
  `receiveFromTotal`), constants injected from `WalletInfo`.
- `core/protocol/inventory_client.dart` — `games()` (parse page globals),
  `items(appid, contextid, {startAssetId})`.
- `core/protocol/market_client.dart` — `priceOverview()`, `sell()`, `myListings()`,
  `cancel()`.
- `services/steam_api_client.dart` — add community GET (text/html for the
  inventory page) and reuse `communityPostJson` (already POSTs form); generate a
  per-account `sessionid` (24 hex) sent as cookie + form param; set `Referer`.
- UI: `ui/market/market_screen.dart` (tabs: 库存 / 我的在售), `inventory_grid`,
  `sell_sheet`, `my_listings`. Entry: account long-press / swipe menu → "库存/市场".
  Themed neon/pixel like the rest.

## Data flow

1. Open Market → `games()` (also caches `WalletInfo`) → pick game → `items()`
   (infinite scroll) → grid (non-marketable greyed).
2. Tap item → sell sheet → `priceOverview()` reference → user sets price (two
   linked fields via `MarketFees`) → `sell()` → if `requires_confirmation`, run
   the mobile-confirmation flow (auto if the market auto-confirm setting is on).
3. My listings → `myListings()` → rows + cancel → `cancel()` → refresh.

## Error handling

- Stale session → `AutoLogin.ensureSession` then retry.
- Private inventory / market not enabled / wallet locked / Guard <15 days →
  surface Steam's message.
- priceoverview rate-limited → allow manual pricing.

## Testing

- Unit: `MarketFees` (the 9 ground-truth samples + round-trip), inventory JSON
  merge, `g_rgAppContextData` / `g_rgWalletInfo` parse, priceoverview parse,
  mylistings parse. Fixtures only, no live network.
