# 交易报价 + 待办中心 实施计划（计划 1/2）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 确认页升级为"待办中心"（确认/报价双页签，邀请页签由计划 2 加入），新增交易报价的查看、就地接受（长按+加速震动）/拒绝/取消，接受后与 mobileconf 确认联动；补全 mobileconf 确认类型标签。

**Architecture:** 新增 `TradeOffersClient`（读取走文档化 `IEconService` JSON API，写操作走 `steamcommunity.com/tradeoffer/*` 社区端点，与 `MarketClient` 同一套 sessionid 模式）；`ConfirmationsScreen` 拆为 `PendingScreen`（Tab 容器）+ `ConfirmationsTab` + `TradeOffersTab`。所有新代码遵循 core（纯 Dart 可单测）/ services / ui 分层。

**Tech Stack:** Flutter 3.44.x / Dart 3.12，Riverpod，dio（经由现有 `SteamApiClient`），flutter_test。无新增依赖。

**对 spec 的两处偏差**（理由记录）：
1. "历史"分段用 `GetTradeOffers` 的 `historical_only=1` 实现，不用 `GetTradeHistory` —— 同一响应形状、同一解析器，少一半代码；
2. 拒绝/取消主路径用社区端点 `/tradeoffer/<id>/decline|cancel`（与接受同一套 sessionid 鉴权，行为确定），`IEconService/DeclineTradeOffer` 的 access_token 鉴权真机验证后可再切换。

**每个 commit 末尾都带 trailer（CLAUDE.md 约定）：**

```
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823
```

**验证命令**（每个 Task 收尾必跑）：`cd app && flutter analyze && flutter test`

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `app/lib/src/core/models/confirmation.dart`（改） | `ConfirmationType` 补 4/5/6/9/11 |
| `app/lib/src/core/models/trade_offer.dart`（新） | `TradeOffer` / `TradeAsset` / `TradeOfferState` 纯模型 + JSON 解析 |
| `app/lib/src/core/protocol/trade_offers_client.dart`（新） | 报价列表/计数/接受/拒绝/取消 + miniprofile |
| `app/lib/src/services/steam_api_client.dart`（改） | 新增 `apiGetJson`（api.steampowered.com 的 JSON GET） |
| `app/lib/src/app/providers.dart`（改） | `tradeOffersClientProvider` |
| `app/lib/src/ui/widgets/hold_button.dart`（新） | 统一长按确认按钮（pill/round 两变体，环形进度 + 加速震动，受设置开关控制） |
| `app/lib/src/app/settings_store.dart`（改） | `hold_confirm` / `haptics` 开关持久化 |
| `app/lib/src/ui/settings_screen.dart`（改） | 两个开关行 |
| `app/lib/src/ui/pending/pending_screen.dart`（新） | 待办中心 Tab 容器 + 角标 |
| `app/lib/src/ui/pending/confirmations_tab.dart`（新） | 原确认页 body 迁移为页签 |
| `app/lib/src/ui/pending/trade_offers_tab.dart`（新） | 报价页签：分段器 + 列表 |
| `app/lib/src/ui/pending/offer_card.dart`（新） | 可展开报价卡 |
| `app/lib/src/ui/confirmations_screen.dart`（删） | 被 pending/ 取代 |
| `app/lib/src/ui/home_screen.dart`（改） | 'confirm' 动作改推 `PendingScreen` |
| `app/lib/l10n/app_en.arb`、`app_zh.arb`（改） | 新字符串 |
| `app/test/core/confirmation_type_test.dart`（新） | 类型映射测试 |
| `app/test/core/trade_offer_model_test.dart`（新） | 模型解析测试（内嵌 fixture） |
| `app/test/core/trade_offers_client_test.dart`（新） | client 测试（fake api） |
| `app/test/widget/hold_button_test.dart`（新） | 震动调度纯函数 + 组件测试（含普通点按退化） |
| `app/test/services/settings_store_test.dart`（新） | 开关默认值与持久化往返 |
| `app/test/ui/pending_screen_test.dart`（新） | 待办中心冒烟 |

---

### Task 1: ConfirmationType 补全

**Files:**
- Modify: `app/lib/src/core/models/confirmation.dart`
- Test: `app/test/core/confirmation_type_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// app/test/core/confirmation_type_test.dart
import 'package:ava/src/core/models/confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

Confirmation _conf(int type) => Confirmation.fromJson({
      'id': '1', 'nonce': '2', 'type': type, 'creation_time': 0,
    });

void main() {
  test('all known Steam confirmation type ids map to named types', () {
    expect(_conf(1).type, ConfirmationType.other);
    expect(_conf(2).type, ConfirmationType.trade);
    expect(_conf(3).type, ConfirmationType.marketListing);
    expect(_conf(4).type, ConfirmationType.featureOptOut);
    expect(_conf(5).type, ConfirmationType.phoneChange);
    expect(_conf(6).type, ConfirmationType.accountRecovery);
    expect(_conf(9).type, ConfirmationType.apiKey);
    expect(_conf(11).type, ConfirmationType.familyJoin);
    expect(_conf(999).type, ConfirmationType.unknown);
    // 字符串形式的 type 同样解析（getlist 偶发字符串数字）。
    expect(_conf(11).type, Confirmation.fromJson({'id': '1', 'nonce': '2', 'type': '11'}).type);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/core/confirmation_type_test.dart`
Expected: FAIL —— `ConfirmationType` 没有 `featureOptOut` 等成员（编译错误即算失败）。

- [ ] **Step 3: 最小实现**

`confirmation.dart` 中替换枚举与 `_mapType`：

```dart
/// A pending mobile confirmation as returned by `/mobileconf/getlist`.
enum ConfirmationType {
  unknown,
  trade,
  marketListing,
  featureOptOut,
  phoneChange,
  accountRecovery,
  apiKey,
  familyJoin,
  other,
}
```

```dart
  // Steam confirmation type ids (steamguard-cli ConfirmationType):
  // 1 generic, 2 trade, 3 market listing, 4 feature opt-out,
  // 5 phone number change, 6 account recovery, 9 web API key creation,
  // 11 join Steam family.
  static ConfirmationType _mapType(dynamic raw) {
    switch (_asInt(raw)) {
      case 1:
        return ConfirmationType.other;
      case 2:
        return ConfirmationType.trade;
      case 3:
        return ConfirmationType.marketListing;
      case 4:
        return ConfirmationType.featureOptOut;
      case 5:
        return ConfirmationType.phoneChange;
      case 6:
        return ConfirmationType.accountRecovery;
      case 9:
        return ConfirmationType.apiKey;
      case 11:
        return ConfirmationType.familyJoin;
      default:
        return ConfirmationType.unknown;
    }
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app && flutter test test/core/confirmation_type_test.dart`
Expected: PASS。再跑 `flutter analyze` —— 此时 `confirmations_screen.dart` 的 switch 不受影响（有 default 分支），应零问题。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/core/models/confirmation.dart app/test/core/confirmation_type_test.dart
git commit -m "feat(conf): map family-join, api-key and security confirmation types

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 2: 确认类型的 l10n 标签与 chip 配色

**Files:**
- Modify: `app/lib/l10n/app_en.arb`、`app/lib/l10n/app_zh.arb`
- Modify: `app/lib/src/ui/confirmations_screen.dart:304-321`

- [ ] **Step 1: ARB 加字符串**（`confTypeOther` 条目后插入；zh 文件同位置）

`app_en.arb`:
```json
  "confTypeFamilyJoin": "Family invite",
  "confTypeApiKey": "API key",
  "confTypePhoneChange": "Phone change",
  "confTypeAccountRecovery": "Account recovery",
  "confTypeFeatureOptOut": "Feature opt-out",
```

`app_zh.arb`:
```json
  "confTypeFamilyJoin": "家庭组邀请",
  "confTypeApiKey": "API 密钥",
  "confTypePhoneChange": "更换手机号",
  "confTypeAccountRecovery": "账户恢复",
  "confTypeFeatureOptOut": "功能退出",
```

- [ ] **Step 2: UI 使用新标签与配色**

`confirmations_screen.dart` 的 `_typeLabel` 与 chip 颜色替换为：

```dart
  String _typeLabel(AppLocalizations l) {
    switch (widget.conf.type) {
      case ConfirmationType.trade:
        return l.confTypeTrade;
      case ConfirmationType.marketListing:
        return l.confTypeMarket;
      case ConfirmationType.familyJoin:
        return l.confTypeFamilyJoin;
      case ConfirmationType.apiKey:
        return l.confTypeApiKey;
      case ConfirmationType.phoneChange:
        return l.confTypePhoneChange;
      case ConfirmationType.accountRecovery:
        return l.confTypeAccountRecovery;
      case ConfirmationType.featureOptOut:
        return l.confTypeFeatureOptOut;
      default:
        return l.confTypeOther;
    }
  }

  /// 安全敏感类型（改手机号/账户恢复/API key）用警示色，家庭组用正向色。
  Color _chipColor(AvaTokens t) {
    switch (widget.conf.type) {
      case ConfirmationType.trade:
        return t.accent;
      case ConfirmationType.familyJoin:
        return t.good;
      case ConfirmationType.apiKey:
      case ConfirmationType.phoneChange:
      case ConfirmationType.accountRecovery:
        return t.bad;
      default:
        return t.accent2;
    }
  }
```

`build` 里 `final isTrade = ...; final chipColor = isTrade ? t.accent : t.accent2;` 两行替换为 `final chipColor = _chipColor(t);`。

- [ ] **Step 3: 验证**

Run: `cd app && flutter analyze && flutter test`
Expected: analyze 零问题（gen-l10n 在构建时自动跑），全部测试 PASS。

- [ ] **Step 4: Commit**

```bash
git add app/lib/l10n/app_en.arb app/lib/l10n/app_zh.arb app/lib/l10n app/lib/src/ui/confirmations_screen.dart
git commit -m "feat(conf): localized labels + chip colors for new confirmation types

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 3: SteamApiClient.apiGetJson

**Files:**
- Modify: `app/lib/src/services/steam_api_client.dart`（`callProtobuf` 之后插入）
- Test: `app/test/core/trade_offers_client_test.dart`（先建骨架，本 task 只测 apiGetJson 不可行——它直接走 dio；改为在 Task 5 通过 fake 覆盖。本 task 仅实现 + analyze）

- [ ] **Step 1: 实现**

```dart
  /// GET against api.steampowered.com returning decoded JSON (non-protobuf
  /// Web API endpoints, e.g. IEconService). [accessToken] is appended as the
  /// `access_token` query param. Returns the decoded top-level object; a
  /// bare 401/403 (expired token) throws [SteamApiException] so callers can
  /// trigger a session refresh, mirroring [callProtobuf]'s contract.
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    final url = '$apiBase/$iface/$method/v$version/';
    dlog('→ GET $iface/$method (json)');
    try {
      final resp = await _dio.get<String>(
        url,
        queryParameters: {'access_token': ?accessToken, ...query},
        options: Options(responseType: ResponseType.plain),
      );
      final status = resp.statusCode ?? 0;
      final body = resp.data ?? '';
      dlog('← $method  HTTP $status  ${body.length}B');
      if (status < 200 || status >= 300) {
        throw SteamApiException(2 /* Fail */, 'HTTP $status', method);
      }
      final decoded = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on DioException catch (e) {
      dlog('  ✗ $method network: ${e.type.name} ${e.response?.statusCode ?? ''}');
      rethrow;
    }
  }
```

- [ ] **Step 2: 验证**

Run: `cd app && flutter analyze && flutter test`
Expected: 零问题，全绿。

- [ ] **Step 3: Commit**

```bash
git add app/lib/src/services/steam_api_client.dart
git commit -m "feat(api): JSON GET transport for non-protobuf Web API endpoints

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 4: TradeOffer 模型 + GetTradeOffers 解析

**Files:**
- Create: `app/lib/src/core/models/trade_offer.dart`
- Test: `app/test/core/trade_offer_model_test.dart`

- [ ] **Step 1: 写失败测试**（fixture 内嵌为 Dart 字符串，覆盖：描述关联、赠送判定、白给判定、partner steamid64 换算、escrow、字符串数字容错）

```dart
// app/test/core/trade_offer_model_test.dart
import 'dart:convert';

import 'package:ava/src/core/models/trade_offer.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = '''
{"response": {
  "trade_offers_received": [
    {"tradeofferid": "7001", "accountid_other": 123, "message": "hi",
     "expiration_time": 1800000000, "trade_offer_state": 2,
     "items_to_give": [],
     "items_to_receive": [
       {"appid": 730, "contextid": "2", "assetid": "111", "classid": "9", "instanceid": "0", "amount": "1"}
     ],
     "is_our_offer": false, "time_created": 1752500000, "time_updated": 1752500000,
     "escrow_end_date": 0, "confirmation_method": 0}
  ],
  "trade_offers_sent": [
    {"tradeofferid": "7002", "accountid_other": 456, "trade_offer_state": 9,
     "items_to_give": [
       {"appid": 730, "contextid": "2", "assetid": "222", "classid": "8", "instanceid": "0", "amount": "1"}
     ],
     "items_to_receive": [],
     "is_our_offer": true, "time_created": 1752400000, "time_updated": 1752400000,
     "escrow_end_date": 1753000000, "confirmation_method": 2}
  ],
  "descriptions": [
    {"appid": 730, "classid": "9", "instanceid": "0", "icon_url": "abc",
     "name": "AK-47 | Redline", "market_hash_name": "AK-47 | Redline (Field-Tested)",
     "name_color": "D2D2D2", "type": "Rifle", "tradable": 1},
    {"appid": 730, "classid": "8", "instanceid": "0", "icon_url": "def",
     "name": "Glock", "market_hash_name": "Glock", "name_color": "", "type": "Pistol", "tradable": 1}
  ]
}}
''';

void main() {
  final page = TradeOffersPage.fromResponse(
      jsonDecode(_fixture)['response'] as Map<String, dynamic>);

  test('received/sent split and description join', () {
    expect(page.received, hasLength(1));
    expect(page.sent, hasLength(1));
    final r = page.received.single;
    expect(r.id, '7001');
    expect(r.itemsToReceive.single.name, 'AK-47 | Redline');
    expect(r.itemsToReceive.single.iconUrl, isNotEmpty);
    expect(r.itemsToReceive.single.nameColor, 'D2D2D2');
  });

  test('gift and one-sided detection', () {
    expect(page.received.single.isGift, isTrue);      // 只收不给
    expect(page.received.single.isOneSidedGive, isFalse);
    expect(page.sent.single.isOneSidedGive, isTrue);  // 只给不收
  });

  test('partner steamid64 derived from accountid_other', () {
    expect(page.received.single.partnerSteamId, 76561197960265728 + 123);
  });

  test('state and escrow parse', () {
    expect(page.received.single.state, TradeOfferState.active);
    expect(page.sent.single.state, TradeOfferState.needsConfirmation);
    expect(page.sent.single.escrowEndDate, 1753000000);
  });

  test('missing description keeps asset with empty name', () {
    final noDesc = TradeOffersPage.fromResponse(jsonDecode('''
      {"trade_offers_received": [{"tradeofferid": "1", "accountid_other": 1,
        "trade_offer_state": 2,
        "items_to_receive": [{"appid": 1, "contextid": "2", "assetid": "3",
          "classid": "99", "instanceid": "0", "amount": "1"}]}]}
    ''') as Map<String, dynamic>);
    expect(noDesc.received.single.itemsToReceive.single.name, isEmpty);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/core/trade_offer_model_test.dart`
Expected: FAIL（`trade_offer.dart` 不存在）。

- [ ] **Step 3: 实现模型**

```dart
// app/lib/src/core/models/trade_offer.dart
import 'steam_item.dart' show itemImageUrl;

/// `trade_offer_state` values from IEconService/GetTradeOffers.
enum TradeOfferState {
  invalid, // 1
  active, // 2
  accepted, // 3
  countered, // 4
  expired, // 5
  canceled, // 6
  declined, // 7
  invalidItems, // 8
  needsConfirmation, // 9
  canceledBySecondFactor, // 10
  inEscrow, // 11
  unknown,
}

TradeOfferState _stateFrom(dynamic raw) {
  final v = _asInt(raw);
  return (v >= 1 && v <= 11)
      ? TradeOfferState.values[v - 1]
      : TradeOfferState.unknown;
}

/// One asset in a trade offer, joined with its description (when present).
class TradeAsset {
  final int appid;
  final String contextId;
  final String assetId;
  final String classId;
  final String instanceId;
  final int amount;
  final String name;
  final String marketHashName;
  final String iconUrl;
  final String nameColor; // hex without '#', '' when absent
  final String type;

  const TradeAsset({
    required this.appid,
    required this.contextId,
    required this.assetId,
    required this.classId,
    required this.instanceId,
    required this.amount,
    this.name = '',
    this.marketHashName = '',
    this.iconUrl = '',
    this.nameColor = '',
    this.type = '',
  });

  factory TradeAsset.fromJson(
      Map<String, dynamic> json, Map<String, Map<String, dynamic>> descByKey) {
    final d = descByKey['${json['classid']}_${json['instanceid']}'];
    return TradeAsset(
      appid: _asInt(json['appid']),
      contextId: '${json['contextid']}',
      assetId: '${json['assetid']}',
      classId: '${json['classid']}',
      instanceId: '${json['instanceid']}',
      amount: _asInt(json['amount']),
      name: (d?['name'] ?? '') as String,
      marketHashName: (d?['market_hash_name'] ?? '') as String,
      iconUrl: d?['icon_url'] != null ? itemImageUrl(d!['icon_url'] as String?) : '',
      nameColor: (d?['name_color'] ?? '') as String,
      type: (d?['type'] ?? '') as String,
    );
  }
}

/// A trade offer as returned by IEconService/GetTradeOffers.
class TradeOffer {
  /// SteamID64 = accountid + this constant (individual/public/desktop).
  static const int steamId64Base = 76561197960265728;

  final String id;
  final int partnerAccountId;
  final String message;
  final TradeOfferState state;
  final bool isOurOffer;
  final List<TradeAsset> itemsToGive;
  final List<TradeAsset> itemsToReceive;
  final int timeCreated;
  final int timeUpdated;
  final int expirationTime;
  final int escrowEndDate;

  const TradeOffer({
    required this.id,
    required this.partnerAccountId,
    required this.message,
    required this.state,
    required this.isOurOffer,
    required this.itemsToGive,
    required this.itemsToReceive,
    required this.timeCreated,
    required this.timeUpdated,
    required this.expirationTime,
    required this.escrowEndDate,
  });

  int get partnerSteamId => steamId64Base + partnerAccountId;

  /// 对方白给：不需要我们付出任何物品。钓鱼报价常伪装成赠送，UI 不得因此
  /// 弱化接受门槛。
  bool get isGift => itemsToGive.isEmpty && itemsToReceive.isNotEmpty;

  /// 我们只给不收 —— 红色警告。
  bool get isOneSidedGive => itemsToReceive.isEmpty && itemsToGive.isNotEmpty;

  factory TradeOffer.fromJson(
      Map<String, dynamic> json, Map<String, Map<String, dynamic>> descByKey) {
    List<TradeAsset> assets(dynamic list) => ((list as List?) ?? const [])
        .map((e) => TradeAsset.fromJson(e as Map<String, dynamic>, descByKey))
        .toList();
    return TradeOffer(
      id: '${json['tradeofferid']}',
      partnerAccountId: _asInt(json['accountid_other']),
      message: (json['message'] ?? '') as String,
      state: _stateFrom(json['trade_offer_state']),
      isOurOffer: json['is_our_offer'] == true,
      itemsToGive: assets(json['items_to_give']),
      itemsToReceive: assets(json['items_to_receive']),
      timeCreated: _asInt(json['time_created']),
      timeUpdated: _asInt(json['time_updated']),
      expirationTime: _asInt(json['expiration_time']),
      escrowEndDate: _asInt(json['escrow_end_date']),
    );
  }
}

/// The parsed `response` object of GetTradeOffers.
class TradeOffersPage {
  final List<TradeOffer> received;
  final List<TradeOffer> sent;
  const TradeOffersPage(this.received, this.sent);

  factory TradeOffersPage.fromResponse(Map<String, dynamic> response) {
    final descByKey = <String, Map<String, dynamic>>{};
    for (final d in (response['descriptions'] as List?) ?? const []) {
      final m = d as Map<String, dynamic>;
      descByKey['${m['classid']}_${m['instanceid']}'] = m;
    }
    List<TradeOffer> offers(String key) => ((response[key] as List?) ?? const [])
        .map((e) => TradeOffer.fromJson(e as Map<String, dynamic>, descByKey))
        .toList();
    return TradeOffersPage(
        offers('trade_offers_received'), offers('trade_offers_sent'));
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is double) return v.toInt();
  return 0;
}
```

注意：`steam_item.dart` 的 `itemImageUrl` 已存在（`steam_item.dart:168`），直接复用。

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app && flutter test test/core/trade_offer_model_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/core/models/trade_offer.dart app/test/core/trade_offer_model_test.dart
git commit -m "feat(trade): TradeOffer model with description join + gift/one-sided detection

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 5: TradeOffersClient — 读取（列表 / 计数 / miniprofile）

**Files:**
- Create: `app/lib/src/core/protocol/trade_offers_client.dart`
- Test: `app/test/core/trade_offers_client_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// app/test/core/trade_offers_client_test.dart
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/trade_offers_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake API：记录调用并回放响应。apiGetJson / communityPostJson 双通道。
class _FakeApi extends SteamApiClient {
  Map<String, dynamic> apiResponse = const {};
  Map<String, dynamic> postResponse = const {};
  String? lastMethod;
  Map<String, dynamic>? lastQuery;
  String? lastPostPath;
  Map<String, dynamic>? lastForm;
  Map<String, String>? lastCookies;
  String? lastReferer;

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    lastMethod = '$iface/$method';
    lastQuery = {...query, if (accessToken != null) 'access_token': accessToken};
    return apiResponse;
  }

  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    lastPostPath = path;
    lastForm = form;
    lastCookies = cookies;
    lastReferer = referer;
    return postResponse;
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
      session: SessionData(
        steamId: 76561198000000123,
        accessToken: 'tok',
        refreshToken: 'r',
      ),
    );

void main() {
  group('fetch', () {
    test('active received+sent uses documented params and parses', () async {
      final api = _FakeApi()
        ..apiResponse = {
          'response': {
            'trade_offers_received': [
              {'tradeofferid': '1', 'accountid_other': 5, 'trade_offer_state': 2,
               'items_to_receive': [
                 {'appid': 1, 'contextid': '2', 'assetid': '3',
                  'classid': '9', 'instanceid': '0', 'amount': '1'}
               ]},
            ],
          },
        };
      final page = await TradeOffersClient(api).fetch(_account());
      expect(page.received, hasLength(1));
      expect(api.lastMethod, 'IEconService/GetTradeOffers');
      expect(api.lastQuery!['get_received_offers'], '1');
      expect(api.lastQuery!['get_sent_offers'], '1');
      expect(api.lastQuery!['get_descriptions'], '1');
      expect(api.lastQuery!['active_only'], '1');
      expect(api.lastQuery!['access_token'], 'tok');
    });

    test('historical fetch flips the flags', () async {
      final api = _FakeApi()..apiResponse = {'response': {}};
      await TradeOffersClient(api).fetch(_account(), historical: true);
      expect(api.lastQuery!['active_only'], '0');
      expect(api.lastQuery!['historical_only'], '1');
    });

    test('missing access token throws before any network call', () async {
      final api = _FakeApi();
      final noToken = SteamGuardAccount(
          session: SessionData(steamId: 1, refreshToken: 'r'));
      expect(() => TradeOffersClient(api).fetch(noToken),
          throwsA(isA<MissingAccessTokenException>()));
      expect(api.lastMethod, isNull);
    });
  });

  test('summary returns pending received count', () async {
    final api = _FakeApi()
      ..apiResponse = {'response': {'pending_received_count': 3,
                                    'new_received_count': 1}};
    expect(await TradeOffersClient(api).pendingReceivedCount(_account()), 3);
    expect(api.lastMethod, 'IEconService/GetTradeOffersSummary');
  });
}
```

（`MissingAccessTokenException` 复用 `qr_approval_client.dart` 里的定义 —— 把它 import 进来。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/core/trade_offers_client_test.dart`
Expected: FAIL（client 不存在）。

- [ ] **Step 3: 实现读取部分**

```dart
// app/lib/src/core/protocol/trade_offers_client.dart
import 'dart:math';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/trade_offer.dart';
import 'qr_approval_client.dart' show MissingAccessTokenException;

/// Result of accepting a trade offer.
class TradeAcceptResult {
  final bool success;
  final bool needsMobileConfirmation;
  final String? message;
  const TradeAcceptResult({
    required this.success,
    this.needsMobileConfirmation = false,
    this.message,
  });
}

/// Trade offers for one account: list/count via the documented IEconService
/// JSON API (access_token auth), accept/decline/cancel via the community
/// `tradeoffer` endpoints (same sessionid pattern as [MarketClient]).
class TradeOffersClient {
  final SteamApiClient api;
  TradeOffersClient(this.api);

  final _rand = Random.secure();
  String _newSessionId() {
    const hex = '0123456789abcdef';
    return List.generate(24, (_) => hex[_rand.nextInt(16)]).join();
  }

  Map<String, String> _cookies(SteamGuardAccount a, String sessionId) => {
        'steamLoginSecure': '${a.steamId}||${a.session.accessToken ?? ''}',
        'sessionid': sessionId,
        'mobileClient': 'android',
      };

  String _requireToken(SteamGuardAccount account) {
    final token = account.session.accessToken;
    if (token == null || token.isEmpty) {
      throw const MissingAccessTokenException();
    }
    return token;
  }

  /// Active (default) or historical offers, both directions, with
  /// descriptions joined. Historical == the "历史" segment.
  Future<TradeOffersPage> fetch(SteamGuardAccount account,
      {bool historical = false}) async {
    final token = _requireToken(account);
    final json = await api.apiGetJson(
      'IEconService',
      'GetTradeOffers',
      {
        'get_received_offers': '1',
        'get_sent_offers': '1',
        'get_descriptions': '1',
        'language': api.steamLanguage,
        'active_only': historical ? '0' : '1',
        'historical_only': historical ? '1' : '0',
      },
      accessToken: token,
    );
    final page = TradeOffersPage.fromResponse(
        (json['response'] as Map<String, dynamic>?) ?? const {});
    dlog('trade offers: ${page.received.length} received, '
        '${page.sent.length} sent (historical=$historical)');
    return page;
  }

  /// Count of pending received offers (tab badge).
  Future<int> pendingReceivedCount(SteamGuardAccount account) async {
    final token = _requireToken(account);
    final json = await api.apiGetJson(
        'IEconService', 'GetTradeOffersSummary', const {},
        accessToken: token);
    final resp = (json['response'] as Map<String, dynamic>?) ?? const {};
    final v = resp['pending_received_count'];
    return v is int ? v : int.tryParse('$v') ?? 0;
  }

  /// Partner display info via the community miniprofile endpoint (no auth).
  /// Returns (personaName, avatarUrl); empty strings on failure.
  Future<(String, String)> miniProfile(int accountId) async {
    try {
      final json = await api.communityGetJson(
          '/miniprofile/$accountId/json', const {});
      return ((json['persona_name'] ?? '') as String,
          (json['avatar_url'] ?? '') as String);
    } catch (_) {
      return ('', '');
    }
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app && flutter test test/core/trade_offers_client_test.dart && cd .. `
Expected: PASS。`flutter analyze` 零问题。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/core/protocol/trade_offers_client.dart app/test/core/trade_offers_client_test.dart
git commit -m "feat(trade): TradeOffersClient reads via documented IEconService JSON API

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 6: TradeOffersClient — 写操作（接受 / 拒绝 / 取消）

**Files:**
- Modify: `app/lib/src/core/protocol/trade_offers_client.dart`
- Test: `app/test/core/trade_offers_client_test.dart`（追加 group）

- [ ] **Step 1: 追加失败测试**

```dart
  group('write ops (community tradeoffer endpoints)', () {
    test('accept posts sessionid+partner with referer, detects mobileconf', () async {
      final api = _FakeApi()
        ..postResponse = {'tradeid': '900', 'needs_mobile_confirmation': true};
      final offer = TradeOffer(
        id: '7001', partnerAccountId: 123, message: '',
        state: TradeOfferState.active, isOurOffer: false,
        itemsToGive: const [], itemsToReceive: const [],
        timeCreated: 0, timeUpdated: 0, expirationTime: 0, escrowEndDate: 0,
      );
      final r = await TradeOffersClient(api).accept(_account(), offer);
      expect(r.success, isTrue);
      expect(r.needsMobileConfirmation, isTrue);
      expect(api.lastPostPath, '/tradeoffer/7001/accept');
      expect(api.lastForm!['tradeofferid'], '7001');
      expect(api.lastForm!['partner'], '${76561197960265728 + 123}');
      expect(api.lastForm!['serverid'], '1');
      // sessionid 必须同时进 form 和 cookie 且一致。
      expect(api.lastForm!['sessionid'], api.lastCookies!['sessionid']);
      expect(api.lastReferer, 'https://steamcommunity.com/tradeoffer/7001/');
    });

    test('accept surfaces strError as failure', () async {
      final api = _FakeApi()..postResponse = {'strError': 'trade banned'};
      final offer = TradeOffer(
        id: '1', partnerAccountId: 1, message: '',
        state: TradeOfferState.active, isOurOffer: false,
        itemsToGive: const [], itemsToReceive: const [],
        timeCreated: 0, timeUpdated: 0, expirationTime: 0, escrowEndDate: 0,
      );
      final r = await TradeOffersClient(api).accept(_account(), offer);
      expect(r.success, isFalse);
      expect(r.message, 'trade banned');
    });

    test('decline and cancel post to their endpoints', () async {
      final api = _FakeApi()..postResponse = {'tradeofferid': '7001'};
      expect(await TradeOffersClient(api).decline(_account(), '7001'), isTrue);
      expect(api.lastPostPath, '/tradeoffer/7001/decline');
      expect(await TradeOffersClient(api).cancel(_account(), '7002'), isTrue);
      expect(api.lastPostPath, '/tradeoffer/7002/cancel');
      expect(api.lastForm!['sessionid'], isNotEmpty);
    });
  });
```

（测试文件顶部需要补 `import 'package:ava/src/core/models/trade_offer.dart';`。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/core/trade_offers_client_test.dart`
Expected: FAIL（`accept` 等方法不存在）。

- [ ] **Step 3: 实现写操作**（追加到 `TradeOffersClient`）

```dart
  /// Accepts a received offer. Steam replies `{tradeid, needs_mobile_confirmation}`
  /// on success or `{strError}` on failure. A mobileconf (type 2) usually
  /// follows — the caller routes the user to the confirmations tab.
  Future<TradeAcceptResult> accept(
      SteamGuardAccount account, TradeOffer offer) async {
    _requireToken(account);
    final sid = _newSessionId();
    final json = await api.communityPostJson(
      '/tradeoffer/${offer.id}/accept',
      {
        'sessionid': sid,
        'serverid': '1',
        'tradeofferid': offer.id,
        'partner': '${offer.partnerSteamId}',
        'captcha': '',
      },
      cookies: _cookies(account, sid),
      referer: '${SteamApiClient.communityBase}/tradeoffer/${offer.id}/',
    );
    final err = json['strError'] as String?;
    final ok = err == null &&
        (json.containsKey('tradeid') ||
            json['needs_mobile_confirmation'] == true);
    dlog('tradeoffer accept ${offer.id} -> ok=$ok err=${err ?? '-'}');
    return TradeAcceptResult(
      success: ok,
      needsMobileConfirmation: json['needs_mobile_confirmation'] == true,
      message: err,
    );
  }

  /// Declines a received offer / cancels a sent one. Steam echoes the
  /// offer id on success; an empty body (decoded as {}) also counts —
  /// same contract as [MarketClient.isCancelSuccess].
  Future<bool> decline(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'decline');

  Future<bool> cancel(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'cancel');

  Future<bool> _writeOp(
      SteamGuardAccount account, String offerId, String op) async {
    _requireToken(account);
    final sid = _newSessionId();
    try {
      final json = await api.communityPostJson(
        '/tradeoffer/$offerId/$op',
        {'sessionid': sid},
        cookies: _cookies(account, sid),
        referer: '${SteamApiClient.communityBase}/tradeoffer/$offerId/',
      );
      if (json['needauth'] == true || json['needsauth'] == true) return false;
      if (json['strError'] != null) return false;
      dlog('tradeoffer $op $offerId -> ok');
      return true;
    } catch (e) {
      dlog('tradeoffer $op $offerId failed: $e');
      return false;
    }
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app && flutter test test/core/trade_offers_client_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/core/protocol/trade_offers_client.dart app/test/core/trade_offers_client_test.dart
git commit -m "feat(trade): accept/decline/cancel via community tradeoffer endpoints

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 7: Provider 接线

**Files:**
- Modify: `app/lib/src/app/providers.dart`（`marketClientProvider` 之后）

- [ ] **Step 1: 实现**

```dart
final tradeOffersClientProvider = Provider<TradeOffersClient>(
    (ref) => TradeOffersClient(ref.read(apiClientProvider)));
```

（顶部补 import `../core/protocol/trade_offers_client.dart`。）

- [ ] **Step 2: 验证 + Commit**

Run: `cd app && flutter analyze && flutter test` — 全绿。

```bash
git add app/lib/src/app/providers.dart
git commit -m "chore(app): wire TradeOffersClient provider

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 8: HoldToConfirmButton（长按 + 加速震动）

**Files:**
- Create: `app/lib/src/ui/widgets/hold_button.dart`
- Test: `app/test/widget/hold_button_test.dart`

- [ ] **Step 1: 写失败测试**（震动调度是纯函数，先测它；组件行为用 WidgetTester 长按/中断两条路径）

```dart
// app/test/widget/hold_button_test.dart
import 'package:ava/src/ui/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hapticTimesMs', () {
    test('intervals strictly shrink (accelerating feel) and fit duration', () {
      final times = HoldToConfirmButton.hapticTimesMs(900);
      expect(times.first, 0);
      expect(times.last, lessThan(900));
      for (var i = 2; i < times.length; i++) {
        final prev = times[i - 1] - times[i - 2];
        final cur = times[i] - times[i - 1];
        expect(cur, lessThan(prev),
            reason: 'interval $i must be shorter than interval ${i - 1}');
      }
      expect(times.length, greaterThanOrEqualTo(5));
    });
  });

  group('widget', () {
    testWidgets('completes only after full hold', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton(
            label: 'accept',
            color: Colors.green,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      // 短按不触发。
      await tester.tap(find.text('accept'));
      await tester.pumpAndSettle();
      expect(fired, 0);
      // 按满 300ms 触发一次。
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('accept')));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('early release cancels and resets', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton(
            label: 'accept',
            color: Colors.green,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('accept')));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up(); // 提前松手
      await tester.pumpAndSettle();
      expect(fired, 0);
    });

    testWidgets('holdEnabled=false degrades to a plain tap', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton(
            label: 'accept',
            color: Colors.green,
            holdEnabled: false,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      await tester.tap(find.text('accept'));
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('round variant renders icon and holds like pill', (tester) async {
      var fired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToConfirmButton.round(
            icon: Icons.check,
            color: Colors.green,
            duration: const Duration(milliseconds: 300),
            onConfirmed: () => fired++,
          ),
        ),
      ));
      final gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.check)));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/widget/hold_button_test.dart`
Expected: FAIL（文件不存在）。

- [ ] **Step 3: 实现组件**

```dart
// app/lib/src/ui/widgets/hold_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's single hold-to-confirm control for irreversible "accept"
/// actions (trade accepts, family joins, mobileconf accepts): press and hold
/// for [duration]; a progress ring fills and haptic ticks fire at shrinking
/// intervals (an accelerating "charging" feel), ending in a medium impact
/// when the action commits. Early release cancels and resets.
///
/// Two shapes: pill ([HoldToConfirmButton.new] with [label]) and round icon
/// ([HoldToConfirmButton.round] — drop-in for the confirmation card's ✓).
/// [holdEnabled] false (settings toggle) degrades to a plain tap;
/// [hapticsEnabled] false mutes all haptics.
class HoldToConfirmButton extends StatefulWidget {
  final String? label; // pill 变体
  final IconData? icon; // round 变体
  final Color color;
  final Duration duration;
  final VoidCallback onConfirmed;
  final bool enabled;
  final bool holdEnabled;
  final bool hapticsEnabled;

  const HoldToConfirmButton({
    super.key,
    required String this.label,
    required this.color,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 900),
    this.enabled = true,
    this.holdEnabled = true,
    this.hapticsEnabled = true,
  }) : icon = null;

  const HoldToConfirmButton.round({
    super.key,
    required IconData this.icon,
    required this.color,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 900),
    this.enabled = true,
    this.holdEnabled = true,
    this.hapticsEnabled = true,
  }) : label = null;

  /// Haptic tick times (ms since press). Intervals shrink geometrically
  /// (factor 0.72, floor 45ms) so the pulse audibly accelerates. Pure and
  /// deterministic for unit tests.
  static List<int> hapticTimesMs(int totalMs) {
    final times = <int>[0];
    var interval = totalMs * 0.30;
    var t = interval;
    while (t < totalMs) {
      times.add(t.round());
      interval = interval * 0.72 < 45 ? 45 : interval * 0.72;
      t += interval;
    }
    return times;
  }

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);
  late final List<int> _haptics =
      HoldToConfirmButton.hapticTimesMs(widget.duration.inMilliseconds);
  int _nextHaptic = 0;

  void _onTick() {
    final elapsed = _c.value * widget.duration.inMilliseconds;
    while (_nextHaptic < _haptics.length && elapsed >= _haptics[_nextHaptic]) {
      if (widget.hapticsEnabled) HapticFeedback.lightImpact();
      _nextHaptic++;
    }
    setState(() {});
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      if (widget.hapticsEnabled) HapticFeedback.mediumImpact();
      _c.reset();
      _nextHaptic = 0;
      widget.onConfirmed();
    }
  }

  void _start(_) {
    if (!widget.enabled || !widget.holdEnabled) return;
    _nextHaptic = 0;
    _c.forward(from: 0);
  }

  void _cancel([_]) {
    if (_c.status != AnimationStatus.completed) {
      _c.reset();
      _nextHaptic = 0;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _c.value;
    final child = widget.icon != null
        ? SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.4,
                  color: widget.color,
                  backgroundColor: widget.color.withValues(alpha: 0.25),
                ),
                Icon(widget.icon, color: widget.color, size: 18),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.16),
              border: Border.all(color: widget.color),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.4,
                    color: widget.color,
                    backgroundColor: widget.color.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: 8),
                Text(widget.label!,
                    style: TextStyle(
                        color: widget.color, fontWeight: FontWeight.w600)),
              ],
            ),
          );

    return GestureDetector(
      // 长按关闭（设置开关）时退化为普通点按 —— 单条操作即点即行，
      // 批量操作的安全底线由调用方保留弹窗（见 Task 10b）。
      onTap: !widget.holdEnabled && widget.enabled ? widget.onConfirmed : null,
      onTapDown: _start,
      onTapUp: _cancel,
      onTapCancel: _cancel,
      child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: child),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd app && flutter test test/widget/hold_button_test.dart`
Expected: PASS（测试环境里 `HapticFeedback` 走 mock 平台通道，静默 no-op）。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/ui/widgets/hold_button.dart app/test/widget/hold_button_test.dart
git commit -m "feat(ui): unified hold-to-confirm button (pill/round) with accelerating haptics

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 8b: 设置开关 — 长按确认 / 震动反馈

**Files:**
- Modify: `app/lib/src/app/settings_store.dart`
- Modify: `app/lib/src/app/providers.dart`
- Modify: `app/lib/src/ui/settings_screen.dart`
- Modify: `app/lib/src/ui/home_screen.dart:225`、`home_screen.dart:972`（触觉调用点接开关）
- Modify: `app/lib/l10n/app_en.arb`、`app_zh.arb`
- Test: `app/test/services/settings_store_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// app/test/services/settings_store_test.dart
import 'dart:io';

import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// SettingsStore 直接写真实文件（app_settings.json 在 maFiles 旁边），
/// 用临时目录替身而非 MemoryStorageProvider。
class _TmpStorage extends StorageProvider {
  final String dir;
  _TmpStorage(this.dir);
  @override
  Future<String> maFilesDir() async => p.join(dir, 'maFiles');
}

void main() {
  test('hold-confirm and haptics default to true and persist', () async {
    final tmp = await Directory.systemTemp.createTemp('ava_settings');
    try {
      final store = SettingsStore(_TmpStorage(tmp.path));
      expect(await store.loadHoldConfirm(), isTrue);
      expect(await store.loadHaptics(), isTrue);
      await store.saveHoldConfirm(false);
      await store.saveHaptics(false);
      expect(await store.loadHoldConfirm(), isFalse);
      expect(await store.loadHaptics(), isFalse);
    } finally {
      await tmp.delete(recursive: true);
    }
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/services/settings_store_test.dart`
Expected: FAIL（`loadHoldConfirm` 不存在）。

- [ ] **Step 3: SettingsStore 实现**（`loadTheme` 之后追加）

```dart
  /// 长按确认开关（默认开）。关闭后单条接受退回普通点按；
  /// 批量"全部接受"保留弹窗二次确认作为安全底线。
  Future<bool> loadHoldConfirm() async =>
      (await _read())['hold_confirm'] != false;

  Future<void> saveHoldConfirm(bool enabled) async {
    final data = await _read();
    data['hold_confirm'] = enabled;
    await _write(data);
  }

  /// 全局触觉反馈开关（默认开）：长按 tick/完成 impact 及现有触觉调用点。
  Future<bool> loadHaptics() async => (await _read())['haptics'] != false;

  Future<void> saveHaptics(bool enabled) async {
    final data = await _read();
    data['haptics'] = enabled;
    await _write(data);
  }
```

- [ ] **Step 4: providers**（沿用 `SkinController` 的 Notifier 模式，`settingsStoreProvider` 之后追加）

```dart
/// 长按确认开关（默认开），持久化到 app_settings.json。
final holdConfirmProvider =
    NotifierProvider<HoldConfirmController, bool>(HoldConfirmController.new);

class HoldConfirmController extends Notifier<bool> {
  @override
  bool build() {
    ref.read(settingsStoreProvider).loadHoldConfirm().then((v) => state = v);
    return true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(settingsStoreProvider).saveHoldConfirm(enabled);
  }
}

/// 全局触觉反馈开关（默认开）。
final hapticsProvider =
    NotifierProvider<HapticsController, bool>(HapticsController.new);

class HapticsController extends Notifier<bool> {
  @override
  bool build() {
    ref.read(settingsStoreProvider).loadHaptics().then((v) => state = v);
    return true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(settingsStoreProvider).saveHaptics(enabled);
  }
}
```

- [ ] **Step 5: ARB 字符串**

`app_en.arb`：
```json
  "settingsHoldConfirm": "Hold to confirm",
  "settingsHoldConfirmDesc": "Irreversible accepts (trades, confirmations) require press-and-hold. When off, a single tap acts immediately; batch actions still ask first.",
  "settingsHaptics": "Haptic feedback",
  "settingsHapticsDesc": "Vibration ticks while holding to confirm and on completion.",
```
`app_zh.arb`：
```json
  "settingsHoldConfirm": "长按确认",
  "settingsHoldConfirmDesc": "不可逆的接受类操作（交易、确认）需长按生效；关闭后单击立即生效，批量操作仍会弹窗确认。",
  "settingsHaptics": "震动反馈",
  "settingsHapticsDesc": "长按确认过程中与完成时的触觉反馈。",
```

- [ ] **Step 6: 设置页两个开关行**

在 `settings_screen.dart` 的生物识别开关行（`settings_screen.dart:685` 附近）同一分区下追加两行，
**复用该行使用的同一 tile 封装组件与排版**（title/description/trailing Switch 结构）：

```dart
    // 长按确认
    title: l.settingsHoldConfirm,
    description: l.settingsHoldConfirmDesc,
    trailing: Switch(
      value: ref.watch(holdConfirmProvider),
      onChanged: (v) => ref.read(holdConfirmProvider.notifier).set(v),
    ),

    // 震动反馈
    title: l.settingsHaptics,
    description: l.settingsHapticsDesc,
    trailing: Switch(
      value: ref.watch(hapticsProvider),
      onChanged: (v) => ref.read(hapticsProvider.notifier).set(v),
    ),
```

- [ ] **Step 7: 现有触觉调用点接开关**

`home_screen.dart:225`（`HapticFeedback.mediumImpact()`）与 `home_screen.dart:972`
（`HapticFeedback.selectionClick()`）改为先判 `hapticsProvider`；两处所在组件均可拿到
`ref`（ConsumerWidget/ConsumerState）或由父级把布尔传入 —— 以各调用点现有的
参数传递风格为准：

```dart
if (ref.read(hapticsProvider)) HapticFeedback.mediumImpact();
```

- [ ] **Step 8: 验证 + Commit**

Run: `cd app && flutter analyze && flutter test`
Expected: 零问题、全绿。

```bash
git add -A app/lib app/test
git commit -m "feat(settings): hold-to-confirm and haptics toggles

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 9: 待办中心骨架（确认页迁移为页签）

**Files:**
- Create: `app/lib/src/ui/pending/pending_screen.dart`
- Create: `app/lib/src/ui/pending/confirmations_tab.dart`
- Delete: `app/lib/src/ui/confirmations_screen.dart`
- Modify: `app/lib/src/ui/home_screen.dart`（`'confirm'` 动作、菜单文案）
- Modify: `app/lib/l10n/app_en.arb`、`app_zh.arb`
- Test: `app/test/ui/pending_screen_test.dart`

**迁移方式**：`confirmations_screen.dart` 内容整体移入 `confirmations_tab.dart`，类名 `ConfirmationsScreen → ConfirmationsTab`，去掉 `Scaffold`/`AppBar`（`build` 直接返回原 `_buildBody` 内容包一层 `RefreshIndicator` 换掉 AppBar 的刷新按钮），`_ConfCard` 等私有类原样带走。新增构造参数 `onCount`（拉取成功后把待处理数报给父级做角标）。**Steam 语义不变，纯 UI 重排。**

- [ ] **Step 1: ARB 加字符串**

`app_en.arb`：
```json
  "pendingTitle": "Pending",
  "pendingTabConfirmations": "Confirmations",
  "pendingTabOffers": "Trade offers",
```
`app_zh.arb`：
```json
  "pendingTitle": "待办",
  "pendingTabConfirmations": "确认",
  "pendingTabOffers": "报价",
```
同时把 `home_screen.dart:941` 的菜单标签 `l.actionConfirmations` 保留 key、在两个 ARB 里改文案为 "Pending" / "待办"。

- [ ] **Step 2: 写失败冒烟测试**

```dart
// app/test/ui/pending_screen_test.dart
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/pending/pending_screen.dart';
import 'package:ava/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// getlist 回空、GetTradeOffers 回空的 fake —— 冒烟只验证骨架渲染。
class _FakeApi extends SteamApiClient {
  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async =>
      {'success': true, 'conf': []};

  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async =>
      {'response': {}};
}

void main() {
  testWidgets('pending screen renders both tabs and switches', (tester) async {
    final account = SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PendingScreen(account: account),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Confirmations'), findsOneWidget);
    expect(find.text('Trade offers'), findsOneWidget);
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
  });
}
```

注意：`MaterialApp` 需带主题扩展 `AvaTokens`，冒烟测试若因缺 token 报错，参照 `test/ui/` 现有测试的 App 包装方式（复用其 helper；执行者以现有 UI 测试文件为准）。

- [ ] **Step 3: 跑测试确认失败**

Run: `cd app && flutter test test/ui/pending_screen_test.dart`
Expected: FAIL（`pending_screen.dart` 不存在）。

- [ ] **Step 4: 实现 PendingScreen**

```dart
// app/lib/src/ui/pending/pending_screen.dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/models/steam_guard_account.dart';
import '../widgets/scanline_overlay.dart';
import 'confirmations_tab.dart';
import 'trade_offers_tab.dart'; // Task 10 创建；本 task 先建占位（见下）

/// 待办中心：确认 / 报价 双页签（家庭组邀请页签由计划 2 加入）。
/// 页签角标 = 各 tab 拉取成功后上报的待处理数。
class PendingScreen extends StatefulWidget {
  final SteamGuardAccount account;
  const PendingScreen({super.key, required this.account});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  int? _confCount;
  int? _offerCount;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _tab(String label, int? count) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Badge(label: Text('$count')),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pendingTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            _tab(l.pendingTabConfirmations, _confCount),
            _tab(l.pendingTabOffers, _offerCount),
          ],
        ),
      ),
      body: ScanlineOverlay(
        child: TabBarView(
          controller: _tabs,
          children: [
            ConfirmationsTab(
              account: widget.account,
              onCount: (n) => setState(() => _confCount = n),
            ),
            TradeOffersTab(
              account: widget.account,
              onCount: (n) => setState(() => _offerCount = n),
              onGoToConfirmations: () {
                _tabs.animateTo(0);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

本 task 的 `trade_offers_tab.dart` 先放最小占位（Task 10 替换为真实现），保证编译：

```dart
// app/lib/src/ui/pending/trade_offers_tab.dart — 占位，Task 10 实装
import 'package:flutter/material.dart';

import '../../core/models/steam_guard_account.dart';

class TradeOffersTab extends StatelessWidget {
  final SteamGuardAccount account;
  final ValueChanged<int>? onCount;
  final VoidCallback? onGoToConfirmations;
  const TradeOffersTab({
    super.key,
    required this.account,
    this.onCount,
    this.onGoToConfirmations,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 5: 迁移 ConfirmationsTab**

把 `confirmations_screen.dart` 全部内容移到 `confirmations_tab.dart`：
- 类改名 `ConfirmationsScreen → ConfirmationsTab`、`_ConfirmationsScreenState → _ConfirmationsTabState`；
- 构造加 `final ValueChanged<int>? onCount;`；
- `_refresh` 成功分支里 `setState` 后加 `widget.onCount?.call(list.length);`，`_respond` 刷新后同样生效（走 `_refresh`）；
- `build` 去掉 `Scaffold`/`AppBar`/`ScanlineOverlay`，直接返回 `RefreshIndicator(onRefresh: _refresh, child: _buildBody(l, t, confs))`——`_buildBody` 的非列表分支（loading/error/empty）需包 `ListView` 使 RefreshIndicator 可用（`ListView(children: [SizedBox(height: 320, child: Center(...))])` 模式）；
- Task 2 改过的 `_typeLabel`/`_chipColor` 原样带走；
- 删除 `confirmations_screen.dart`；`home_screen.dart` 的 import 与 `'confirm'` 分支改为：

```dart
      case 'confirm':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PendingScreen(account: account)));
        break;
```

（import 改为 `pending/pending_screen.dart`；`home_screen.dart:1026` 右滑注释同步改为 "enter pending center"。）

- [ ] **Step 6: 跑全量验证**

Run: `cd app && flutter analyze && flutter test`
Expected: 零问题、全绿（含新冒烟测试）。

- [ ] **Step 7: Commit**

```bash
git add -A app/lib app/test
git commit -m "refactor(ui): confirmations screen becomes the pending center (tabbed)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 10: 报价页签（分段器 + 可展开卡 + 操作 + 联动）

**Files:**
- Modify: `app/lib/src/ui/pending/trade_offers_tab.dart`（替换占位）
- Create: `app/lib/src/ui/pending/offer_card.dart`
- Modify: `app/lib/l10n/app_en.arb`、`app_zh.arb`
- Test: `app/test/ui/pending_screen_test.dart`（追加交互用例）

- [ ] **Step 1: ARB 加字符串**

`app_en.arb`：
```json
  "offersSegReceived": "Received",
  "offersSegSent": "Sent",
  "offersSegHistory": "History",
  "offersEmpty": "No trade offers.",
  "offerGift": "Gift — you give nothing",
  "offerOneSided": "You give items and receive nothing",
  "offerEscrow": "Items will be held by Steam before delivery",
  "offerAcceptHold": "Hold to accept",
  "offerDecline": "Decline",
  "offerCancel": "Cancel offer",
  "offerReceiveLabel": "You receive",
  "offerGiveLabel": "You give",
  "offerAccepted": "Offer accepted — confirm it in the Confirmations tab",
  "offerActionFailed": "Action failed: {msg}",
  "@offerActionFailed": {"placeholders": {"msg": {"type": "String"}}},
  "offerDeclined": "Offer declined.",
  "offerCanceled": "Offer canceled.",
```
`app_zh.arb`：
```json
  "offersSegReceived": "收到",
  "offersSegSent": "发出",
  "offersSegHistory": "历史",
  "offersEmpty": "没有交易报价。",
  "offerGift": "赠送 — 你无需给出物品",
  "offerOneSided": "你给出物品但一无所获",
  "offerEscrow": "物品将被 Steam 暂挂后交付",
  "offerAcceptHold": "长按接受",
  "offerDecline": "拒绝",
  "offerCancel": "取消报价",
  "offerReceiveLabel": "你收到",
  "offerGiveLabel": "你给出",
  "offerAccepted": "已接受报价 — 请到"确认"页签完成确认",
  "offerActionFailed": "操作失败：{msg}",
  "@offerActionFailed": {"placeholders": {"msg": {"type": "String"}}},
  "offerDeclined": "已拒绝报价。",
  "offerCanceled": "已取消报价。",
```

- [ ] **Step 2: 追加失败测试**（fake 返回一条收到的报价，验证卡片渲染、展开、警示条）

在 `pending_screen_test.dart` 追加：

```dart
  testWidgets('offer card renders, expands, shows gift banner', (tester) async {
    final api = _FakeApiWithOffer();
    final account = SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PendingScreen(account: account),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade offers'));
    await tester.pumpAndSettle();
    // 收起态：摘要行可见，操作按钮不可见。
    expect(find.textContaining('AK-47'), findsNothing);
    expect(find.text('Hold to accept'), findsNothing);
    // 点卡片展开。
    await tester.tap(find.byType(OfferCard));
    await tester.pumpAndSettle();
    expect(find.text('Hold to accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Gift — you give nothing'), findsOneWidget);
  });
```

`_FakeApiWithOffer` 定义（同文件）：

```dart
class _FakeApiWithOffer extends _FakeApi {
  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    if (method == 'GetTradeOffers') {
      return {
        'response': {
          'trade_offers_received': [
            {'tradeofferid': '7001', 'accountid_other': 123,
             'trade_offer_state': 2,
             'items_to_receive': [
               {'appid': 730, 'contextid': '2', 'assetid': '111',
                'classid': '9', 'instanceid': '0', 'amount': '1'}
             ],
             'items_to_give': [],
             'time_created': 1752500000, 'time_updated': 1752500000}
          ],
          'descriptions': [
            {'appid': 730, 'classid': '9', 'instanceid': '0',
             'icon_url': '', 'name': 'AK-47 | Redline',
             'market_hash_name': 'AK-47', 'name_color': 'D2D2D2',
             'type': 'Rifle', 'tradable': 1}
          ],
        },
      };
    }
    return {'response': {}};
  }
}
```

（fake 的 `icon_url` 留空 → 卡片走无图分支，测试环境不发起网络图片请求。）

- [ ] **Step 3: 跑测试确认失败**

Run: `cd app && flutter test test/ui/pending_screen_test.dart`
Expected: FAIL（`OfferCard` 不存在 / 占位 tab 无内容）。

- [ ] **Step 4: 实现 OfferCard**

```dart
// app/lib/src/ui/pending/offer_card.dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/trade_offer.dart';
import '../widgets/ava_panel.dart';
import '../widgets/hold_button.dart';

/// 可展开的报价卡（spec 方案 C）：收起 = 对方 + 时间 + 摘要行；
/// 展开 = 双方物品缩略图 + 警示条 + 拒绝/长按接受。
class OfferCard extends StatelessWidget {
  final TradeOffer offer;
  final bool expanded;
  final bool busy;
  final String personaName; // '' → 显示 SteamID
  final VoidCallback onToggle;
  final VoidCallback? onAccept; // null → 不显示接受（发出/历史）
  final VoidCallback? onDeclineOrCancel;
  final String declineLabel;
  final bool holdEnabled; // 设置开关（Task 8b）
  final bool hapticsEnabled;

  const OfferCard({
    super.key,
    required this.offer,
    required this.expanded,
    required this.busy,
    required this.personaName,
    required this.onToggle,
    required this.declineLabel,
    required this.holdEnabled,
    required this.hapticsEnabled,
    this.onAccept,
    this.onDeclineOrCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final who =
        personaName.isNotEmpty ? personaName : '${offer.partnerSteamId}';

    return Padding(
      padding: context.rInsets(bottom: 10),
      child: AvaPanel(
        padding: context.rInsets(all: 14),
        child: InkWell(
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text, fontSize: context.r(14))),
                  ),
                  Text(_age(offer.timeUpdated),
                      style:
                          TextStyle(color: t.muted, fontSize: context.r(11))),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: t.muted, size: context.r(18)),
                ],
              ),
              SizedBox(height: context.r(6)),
              // 摘要行（收起态核心信息）。
              Text(
                [
                  '↓ ${offer.itemsToReceive.length}',
                  '↑ ${offer.itemsToGive.length}',
                  if (offer.isGift) '🎁',
                ].join('  ·  '),
                style: TextStyle(color: t.muted, fontSize: context.r(12)),
              ),
              if (expanded) ...[
                SizedBox(height: context.r(10)),
                if (offer.itemsToReceive.isNotEmpty)
                  _assetRow(context, t, l.offerReceiveLabel,
                      offer.itemsToReceive, t.good),
                if (offer.itemsToGive.isNotEmpty)
                  _assetRow(context, t, l.offerGiveLabel,
                      offer.itemsToGive, t.bad),
                if (offer.isGift) _banner(context, t.good, l.offerGift),
                if (offer.isOneSidedGive)
                  _banner(context, t.bad, l.offerOneSided),
                if (offer.escrowEndDate > 0)
                  _banner(context, t.accent2, l.offerEscrow),
                SizedBox(height: context.r(10)),
                Row(
                  children: [
                    if (onDeclineOrCancel != null)
                      OutlinedButton(
                        onPressed: busy ? null : onDeclineOrCancel,
                        child: Text(declineLabel),
                      ),
                    const Spacer(),
                    if (onAccept != null)
                      HoldToConfirmButton(
                        label: l.offerAcceptHold,
                        color: t.good,
                        enabled: !busy,
                        holdEnabled: holdEnabled,
                        hapticsEnabled: hapticsEnabled,
                        onConfirmed: onAccept!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _assetRow(BuildContext context, AvaTokens t, String label,
      List<TradeAsset> assets, Color accent) {
    return Padding(
      padding: context.rInsets(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: accent, fontSize: context.r(11))),
          SizedBox(height: context.r(4)),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final a in assets)
                Tooltip(
                  message: a.name,
                  child: Container(
                    width: context.r(40),
                    height: context.r(40),
                    decoration: BoxDecoration(
                      color: t.muted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: a.nameColor.length == 6
                            ? Color(int.parse('FF${a.nameColor}', radix: 16))
                            : t.muted.withValues(alpha: 0.4),
                      ),
                    ),
                    child: a.iconUrl.isEmpty
                        ? Icon(Icons.inventory_2_outlined,
                            color: t.muted, size: context.r(18))
                        : Image.network(a.iconUrl, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, Color color, String text) => Container(
        margin: context.rInsets(top: 4),
        padding: context.rInsets(left: 8, top: 4, right: 8, bottom: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: context.r(11))),
      );

  static String _age(int epoch) {
    if (epoch == 0) return '';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }
}
```

- [ ] **Step 5: 实现 TradeOffersTab**（替换占位）

```dart
// app/lib/src/ui/pending/trade_offers_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/trade_offer.dart';
import '../../core/protocol/trade_offers_client.dart';
import '../../services/session_manager.dart';

enum _Segment { received, sent, history }

/// 报价页签：顶部分段器（收到/发出/历史）+ 可展开报价卡。
/// 接受成功且需要 mobileconf 时回调 [onGoToConfirmations] 切页签。
class TradeOffersTab extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final ValueChanged<int>? onCount;
  final VoidCallback? onGoToConfirmations;
  const TradeOffersTab({
    super.key,
    required this.account,
    this.onCount,
    this.onGoToConfirmations,
  });

  @override
  ConsumerState<TradeOffersTab> createState() => _TradeOffersTabState();
}

class _TradeOffersTabState extends ConsumerState<TradeOffersTab> {
  late final TradeOffersClient _client;
  _Segment _seg = _Segment.received;
  TradeOffersPage? _active;
  TradeOffersPage? _history;
  final _personas = <int, String>{}; // accountid -> persona name
  String? _expandedId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ref.read(tradeOffersClientProvider);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = _seg == _Segment.history
          ? await _client.fetch(widget.account, historical: true)
          : await _client.fetch(widget.account);
      if (!mounted) return;
      setState(() {
        if (_seg == _Segment.history) {
          _history = page;
        } else {
          _active = page;
          widget.onCount?.call(page.received
              .where((o) => o.state == TradeOfferState.active)
              .length);
        }
        _loading = false;
      });
      _loadPersonas(page);
    } catch (e) {
      if (!mounted) return;
      // access_token 过期 → 用 refresh token 换新后重试一次。
      if (await SessionManager(ref.read(apiClientProvider))
          .refresh(widget.account.session)) {
        await ref.read(appControllerProvider).value?.store.save();
        if (mounted) return _refresh();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadPersonas(TradeOffersPage page) async {
    for (final o in [...page.received, ...page.sent]) {
      if (_personas.containsKey(o.partnerAccountId)) continue;
      final (name, _) = await _client.miniProfile(o.partnerAccountId);
      if (!mounted) return;
      if (name.isNotEmpty) {
        setState(() => _personas[o.partnerAccountId] = name);
      }
    }
  }

  List<TradeOffer> get _shown {
    switch (_seg) {
      case _Segment.received:
        return (_active?.received ?? const [])
            .where((o) =>
                o.state == TradeOfferState.active ||
                o.state == TradeOfferState.inEscrow)
            .toList();
      case _Segment.sent:
        return (_active?.sent ?? const [])
            .where((o) =>
                o.state == TradeOfferState.active ||
                o.state == TradeOfferState.needsConfirmation)
            .toList();
      case _Segment.history:
        return [...?_history?.received, ...?_history?.sent]
          ..sort((a, b) => b.timeUpdated.compareTo(a.timeUpdated));
    }
  }

  Future<void> _accept(TradeOffer offer) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await _client.accept(widget.account, offer);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.offerAccepted)));
      if (r.needsMobileConfirmation) widget.onGoToConfirmations?.call();
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.offerActionFailed(r.message ?? '?'))));
    }
  }

  Future<void> _declineOrCancel(TradeOffer offer) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final ok = _seg == _Segment.received
        ? await _client.decline(widget.account, offer.id)
        : await _client.cancel(widget.account, offer.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (_seg == _Segment.received ? l.offerDeclined : l.offerCanceled)
            : l.offerActionFailed('')))); 
    if (ok) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Column(
      children: [
        Padding(
          padding: context.rInsets(left: 16, top: 12, right: 16, bottom: 4),
          child: SegmentedButton<_Segment>(
            segments: [
              ButtonSegment(
                  value: _Segment.received, label: Text(l.offersSegReceived)),
              ButtonSegment(value: _Segment.sent, label: Text(l.offersSegSent)),
              ButtonSegment(
                  value: _Segment.history, label: Text(l.offersSegHistory)),
            ],
            selected: {_seg},
            onSelectionChanged: (s) {
              setState(() => _seg = s.single);
              if (_seg == _Segment.history ? _history == null : _active == null) {
                _refresh();
              }
            },
          ),
        ),
        Expanded(child: _body(l, t)),
      ],
    );
  }

  Widget _body(AppLocalizations l, AvaTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: t.muted, size: context.r(40)),
            SizedBox(height: context.r(12)),
            Text('${l.commonError}: $_error', textAlign: TextAlign.center),
            SizedBox(height: context.r(16)),
            OutlinedButton(onPressed: _refresh, child: Text(l.commonRetry)),
          ],
        ),
      );
    }
    final offers = _shown;
    if (offers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          SizedBox(
            height: 320,
            child: Center(child: Text(l.offersEmpty)),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: context.rInsets(left: 16, top: 8, right: 16, bottom: 16),
        itemCount: offers.length,
        itemBuilder: (context, i) {
          final o = offers[i];
          final actionable = _seg != _Segment.history;
          return OfferCard(
            key: ValueKey(o.id),
            offer: o,
            expanded: _expandedId == o.id,
            busy: _busy,
            holdEnabled: ref.watch(holdConfirmProvider),
            hapticsEnabled: ref.watch(hapticsProvider),
            personaName: _personas[o.partnerAccountId] ?? '',
            onToggle: () =>
                setState(() => _expandedId = _expandedId == o.id ? null : o.id),
            declineLabel:
                _seg == _Segment.received ? l.offerDecline : l.offerCancel,
            onAccept: actionable && _seg == _Segment.received
                ? () => _accept(o)
                : null,
            onDeclineOrCancel:
                actionable ? () => _declineOrCancel(o) : null,
          );
        },
      ),
    );
  }
}
```

（顶部 import `offer_card.dart`。）

- [ ] **Step 6: 跑全量验证**

Run: `cd app && flutter analyze && flutter test`
Expected: 零问题、全绿。

- [ ] **Step 7: Commit**

```bash
git add -A app/lib app/test
git commit -m "feat(trade): trade offers tab — segments, expandable cards, hold-to-accept

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 10b: 确认页交互统一（单条 ✓ 与"全部接受"改长按）

**Files:**
- Modify: `app/lib/src/ui/pending/confirmations_tab.dart`
- Test: `app/test/ui/pending_screen_test.dart`（追加用例）

**规则（spec 追加节）**：接受类 = 长按（开关关闭时单条退普通点按、批量退弹窗）；
拒绝类（单条 ✕、"全部拒绝"弹窗）保持原样。

- [ ] **Step 1: 追加失败测试**

`_FakeApi` 的 `communityGetJson` 改为可配置一条确认（默认仍回空，避免影响既有用例）：

```dart
class _FakeApiWithConf extends _FakeApi {
  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async =>
      {
        'success': true,
        'conf': [
          {'id': '10', 'nonce': '20', 'type': 2, 'type_name': 'Trade',
           'creator_id': '1', 'headline': 'with friend_a',
           'summary': ['item'], 'creation_time': 1752500000, 'icon': ''}
        ],
      };
}
```

追加用例：

```dart
  testWidgets('confirmation accept is a hold button by default', (tester) async {
    final account = SteamGuardAccount(
      accountName: 'acc',
      identitySecret: 'YQ==',
      session: SessionData(
          steamId: 76561198000000123, accessToken: 't', refreshToken: 'r'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_FakeApiWithConf())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PendingScreen(account: account),
      ),
    ));
    await tester.pumpAndSettle();
    // 单条卡片上出现圆形长按接受（HoldToConfirmButton），不再是即点 ✓。
    expect(find.byType(HoldToConfirmButton), findsWidgets);
  });
```

（顶部补 `import 'package:ava/src/ui/widgets/hold_button.dart';`。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd app && flutter test test/ui/pending_screen_test.dart`
Expected: FAIL（确认卡仍是 `_RoundAction` ✓）。

- [ ] **Step 3: 实现**

`confirmations_tab.dart`：

1. `_ConfCard` 加参数 `final bool holdEnabled; final bool hapticsEnabled;`（required），
   构建处把接受按钮替换为：

```dart
              _RoundAction(
                icon: Icons.close,
                color: t.bad,
                onTap: widget.busy ? null : widget.onReject,
              ),
              HoldToConfirmButton.round(
                icon: Icons.check,
                color: t.good,
                enabled: !widget.busy,
                holdEnabled: widget.holdEnabled,
                hapticsEnabled: widget.hapticsEnabled,
                onConfirmed: widget.onAccept,
              ),
```

（`holdEnabled=false` 时组件自身退化为普通点按 —— 行为与原 ✓ 完全一致，
无需在调用方分支。）

2. 列表构建处传参：

```dart
            itemBuilder: (context, i) => _ConfCard(
              key: ValueKey(confs[i].id),
              conf: confs[i],
              index: i,
              busy: _busy,
              holdEnabled: ref.watch(holdConfirmProvider),
              hapticsEnabled: ref.watch(hapticsProvider),
              onAccept: () => _respond([confs[i]], true),
              onReject: () => _respond([confs[i]], false),
            ),
```

3. 批量栏"全部接受"：长按开时直接长按执行（弹窗冗余，移除）；关闭时保留原弹窗路径：

```dart
              ref.watch(holdConfirmProvider)
                  ? HoldToConfirmButton(
                      label: l.confAcceptAll,
                      color: t.good,
                      enabled: !_busy,
                      hapticsEnabled: ref.watch(hapticsProvider),
                      onConfirmed: () => _respond(confs, true),
                    )
                  : FilledButton.icon(
                      onPressed: _busy ? null : () => _respondAll(confs, true),
                      icon: Icon(Icons.check, size: context.r(16)),
                      label: Text(l.confAcceptAll),
                    ),
```

"全部拒绝"按钮与 `_respondAll` 的弹窗逻辑保持不变（拒绝类不走长按）。

- [ ] **Step 4: 跑全量验证**

Run: `cd app && flutter analyze && flutter test`
Expected: 零问题、全绿。

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/ui/pending/confirmations_tab.dart app/test/ui/pending_screen_test.dart
git commit -m "feat(conf): unify accepts behind hold-to-confirm (settings-aware)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: c6beebba-fcf7-4f55-b274-3afcea74e823"
```

---

### Task 11: 收尾 — 全量验证 + 真机联调清单

- [ ] **Step 1: 全量 CI**

Run: `cd app && flutter analyze && flutter test`
Expected: analyze 零问题；全部测试通过（原 167 + 新增 ≥ 12）。

- [ ] **Step 2: 模拟器冒烟**（AVD `ava_test`，emulator-5554，mock 账户 PIN 123456）

```bash
cd app && flutter run -d emulator-5554
```
检查：右滑账户行 → 待办中心两页签渲染；报价页签分段器切换；空态/错误态正常；
确认卡单条接受为长按（震动逐渐加速）；设置里关"长按确认"→ 单条退普通点按、
"全部接受"退弹窗；关"震动反馈"→ 长按无震动、账户行手势无震动。

- [ ] **Step 3: 真机联调清单**（登记为 issue/TODO，勿在真机确认页操作 —— CLAUDE.md 红线）

- [ ] `GetTradeOffers` 真实响应解析（含 icon 渲染、name_color 边框）
- [ ] 接受赠送报价 → `needs_mobile_confirmation` → 自动切确认页签 → type 2 确认出现
- [ ] 拒绝收到 / 取消发出 → 状态刷新
- [ ] 历史分段有数据
- [ ] miniprofile 昵称显示
- [ ] access_token 过期路径（等 token 过期后进入页签 → 自动刷新成功）
- [ ] type 11 家庭组邀请确认显示为"家庭组邀请"chip（配合计划 2 验证）

- [ ] **Step 4: 版本与 CHANGELOG**

按用户 **b** 快捷指令的约定执行（bump `app/pubspec.yaml` version + CHANGELOG 中英条目），由用户触发，不在本计划内自动执行。

---

## Self-Review 记录

- **Spec 覆盖**：确认类型补全（Task 1-2）、待办中心（Task 9）、报价读写（Task 4-6）、统一长按+震动组件（Task 8）、设置开关（Task 8b）、分段器与联动（Task 10）、确认页交互统一（Task 10b）、错误/边界（gift/one-sided/escrow banner、auth 刷新、页签级错误态）、i18n、测试、真机清单（Task 11）。家庭组邀请页签 = 计划 2（spec 允许分期）。spec 的 `GetTradeOffersSummary` 用于角标 —— 实现为 `pendingReceivedCount`（Task 5），页签内角标直接用列表长度（Task 10），Summary 留给主屏角标（计划 2 或后续）。
- **占位符扫描**：Task 9 的 `trade_offers_tab.dart` 占位在 Task 10 被完整替换，非遗留。Task 8b Step 6/7 指向 settings_screen/home_screen 的既有封装组件（执行者按 `settings_screen.dart:685`、`home_screen.dart:225/972` 现场对齐），属"跟随现有模式"而非待定项。
- **类型一致性**：`TradeOffersPage.fromResponse`（Task 4）↔ client（Task 5）；`OfferCard` 构造参数（含 `holdEnabled`/`hapticsEnabled`）↔ Task 10 调用点；`HoldToConfirmButton`/`HoldToConfirmButton.round` 签名 ↔ Task 8 测试、Task 10/10b 调用点；`holdConfirmProvider`/`hapticsProvider`（Task 8b）↔ Task 10/10b 的 `ref.watch`；`onCount`/`onGoToConfirmations` 贯穿 Task 9-10 一致。
- **执行顺序依赖**：Task 8b（providers）必须先于 Task 10/10b（消费开关）；Task 8 先于 8b 无硬依赖但保持编号顺序执行即可。
