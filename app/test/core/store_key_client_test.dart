import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/store_key_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the store POST instead of making one, and replies with [reply].
class _FakeApi extends SteamApiClient {
  final Map<String, dynamic> reply;

  /// Extra cookies the fake store hands back from the bootstrap GET — the
  /// real one Set-Cookies `steamCountry` / `browserid`, and may reissue
  /// `sessionid`.
  final Map<String, String> issued;

  String? path;
  Map<String, dynamic>? form;
  Map<String, String>? cookies;
  String? referer;
  String? bootstrapPath;
  int calls = 0;
  int bootstraps = 0;

  _FakeApi(this.reply, {this.issued = const {}});

  @override
  Future<Map<String, String>> storeBootstrap(
      String path, Map<String, String> cookies) async {
    bootstraps++;
    bootstrapPath = path;
    return {...cookies, ...issued};
  }

  @override
  Future<Map<String, dynamic>> storePostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    calls++;
    this.path = path;
    this.form = form;
    this.cookies = cookies;
    this.referer = referer;
    return reply;
  }
}

SteamGuardAccount _account({String? accessToken = 'tok'}) => SteamGuardAccount(
      identitySecret: 'YQ==',
      session: SessionData(
        steamId: 76561198000000123,
        accessToken: accessToken,
        refreshToken: 'r',
      ),
    );

/// A realistic success body: `success: 1`, a zero result detail, and a receipt
/// whose line items name the granted packages. Field names follow Valve's own
/// `registerkey.js` (`line_item_description`).
Map<String, dynamic> _successBody() => {
      'success': 1,
      'purchase_result_details': 0,
      'purchase_receipt_info': {
        'purchasestatus': 1,
        'resultdetail': 0,
        'line_items': [
          {
            'lineitemid': '0',
            'packageid': 12345,
            'line_item_description': 'Portal 2',
          },
          {
            'lineitemid': '1',
            'packageid': 12346,
            'line_item_description': 'Portal',
          },
        ],
      },
    };

void main() {
  group('StoreKeyClient.normalize', () {
    test('uppercases and strips every kind of whitespace', () {
      expect(StoreKeyClient.normalize(' abcde-fghij\t-klmno \n'),
          'ABCDE-FGHIJ-KLMNO');
    });

    test('leaves punctuation and length exactly as typed', () {
      // Key layouts vary (15-char triplets, 25-char quintuplets, dashless
      // promo codes) — re-grouping the dashes would corrupt shapes we don't
      // know about, so normalize must not touch them.
      expect(StoreKeyClient.normalize('abcdefghijklmnopqrstuvwxy'),
          'ABCDEFGHIJKLMNOPQRSTUVWXY');
      expect(StoreKeyClient.normalize('AB-CD--EF'), 'AB-CD--EF');
    });

    test('empty and whitespace-only input normalize to empty', () {
      expect(StoreKeyClient.normalize('   \t\n '), '');
    });
  });

  group('KeyRedeemResult.parse', () {
    test('success:1 + detail 0 activates and reads the product names', () {
      final r = KeyRedeemResult.parse(_successBody());
      expect(r.success, isTrue);
      expect(r.detail, 0);
      expect(r.error, isNull);
      expect(r.products, ['Portal 2', 'Portal']);
    });

    test('success with no line items is still a success, with no products', () {
      final r = KeyRedeemResult.parse(
          const {'success': 1, 'purchase_result_details': 0});
      expect(r.success, isTrue);
      expect(r.products, isEmpty);
    });

    test('success:1 wins even with a non-zero detail — Valve\'s own branch', () {
      // registerkey.js renders the receipt whenever success == 1 and only
      // reads purchase_result_details on the failure branch. Being stricter
      // than Steam's own client would report an activated key as failed and
      // send the user to burn another attempt on a key they now own.
      final r = KeyRedeemResult.parse(
          const {'success': 1, 'purchase_result_details': 14});
      expect(r.success, isTrue);
    });

    test('a missing success flag is a failure', () {
      final r =
          KeyRedeemResult.parse(const {'purchase_result_details': 14});
      expect(r.success, isFalse);
      expect(r.error, KeyRedeemError.invalidKey);
    });

    test('detail falls back to the receipt, in either spelling', () {
      // `result_detail` is the protobuf spelling; `resultdetail` is what web
      // captures show. Production sends one of the two and we can't test which.
      for (final key in ['result_detail', 'resultdetail']) {
        final r = KeyRedeemResult.parse({
          'success': 2,
          'purchase_receipt_info': {'purchasestatus': 2, key: 15},
        });
        expect(r.success, isFalse, reason: key);
        expect(r.detail, 15, reason: key);
        expect(r.error, KeyRedeemError.alreadyActivated, reason: key);
      }
    });

    test('an empty body is a failure, never a silent success', () {
      // The shared JSON decoder returns {} for a bodiless 200. There is no
      // receipt to show and no proof the key was consumed — claiming success
      // would be the worse error.
      final r = KeyRedeemResult.parse(const {});
      expect(r.success, isFalse);
      expect(r.detail, -1);
      expect(r.error, KeyRedeemError.unknown);
    });

    test('string-encoded numbers are coerced like the rest of Steam JSON', () {
      final r = KeyRedeemResult.parse(
          const {'success': '1', 'purchase_result_details': '0'});
      expect(r.success, isTrue);
    });

    test('line items without a usable description are skipped', () {
      final r = KeyRedeemResult.parse(const {
        'success': 1,
        'purchase_result_details': 0,
        'purchase_receipt_info': {
          'line_items': [
            {'packageid': 1},
            {'packageid': 2, 'line_item_description': '   '},
            {'packageid': 3, 'line_item_description': '  Half-Life  '},
            'not a map',
          ],
        },
      });
      expect(r.products, ['Half-Life']);
    });

    test('packageName is accepted as the alternate line-item spelling', () {
      final r = KeyRedeemResult.parse(const {
        'success': 1,
        'purchase_receipt_info': {
          'line_items': [
            {'packageid': 1, 'packageName': 'Team Fortress 2'},
          ],
        },
      });
      expect(r.products, ['Team Fortress 2']);
    });
  });

  group('KeyRedeemResult.errorFor', () {
    test('maps exactly the codes registerkey.js has distinct copy for', () {
      // Values are EPurchaseResultDetail (SteamKit SteamLanguage.cs).
      expect(KeyRedeemResult.errorFor(9), KeyRedeemError.alreadyOwned);
      expect(KeyRedeemResult.errorFor(13), KeyRedeemError.regionLocked);
      expect(KeyRedeemResult.errorFor(14), KeyRedeemError.invalidKey);
      expect(KeyRedeemResult.errorFor(15), KeyRedeemError.alreadyActivated);
      expect(KeyRedeemResult.errorFor(24), KeyRedeemError.needsBaseProduct);
      expect(KeyRedeemResult.errorFor(36), KeyRedeemError.needsPs3Login);
      expect(KeyRedeemResult.errorFor(53), KeyRedeemError.rateLimited);
    });

    test('anything else stays unknown so the UI quotes the raw code', () {
      // 4 (Timeout) and 50 (CannotRedeemCodeFromClient) are real
      // EPurchaseResultDetail values, but Valve's page folds them into its
      // generic message — so we quote the number rather than invent copy.
      expect(KeyRedeemResult.errorFor(4), KeyRedeemError.unknown);
      expect(KeyRedeemResult.errorFor(50), KeyRedeemError.unknown);
      expect(KeyRedeemResult.errorFor(-1), KeyRedeemError.unknown);
      expect(KeyRedeemResult.errorFor(999), KeyRedeemError.unknown);
    });
  });

  group('StoreKeyClient.redeem', () {
    test('posts the normalized key with a matching sessionid cookie', () async {
      final api = _FakeApi(_successBody());
      final r = await StoreKeyClient(api)
          .redeem(_account(), ' abcde-fghij-klmno ');

      expect(r.success, isTrue);
      expect(api.path, '/account/ajaxregisterkey/');
      expect(api.form!['product_key'], 'ABCDE-FGHIJ-KLMNO');
      // The cookie and the form field must agree, whichever sessionid won.
      expect(api.cookies!['sessionid'], api.form!['sessionid']);
      expect(api.cookies!['steamLoginSecure'], '76561198000000123||tok');
      expect(api.referer, contains('store.steampowered.com'));
    });

    test('loads the activation page before posting', () async {
      // Without this the store 302s the POST back to its own URL (it wants to
      // Set-Cookie steamCountry/browserid first) and the key is never sent.
      final api = _FakeApi(_successBody());
      await StoreKeyClient(api).redeem(_account(), 'ABCDE');
      expect(api.bootstraps, 1);
      expect(api.bootstrapPath, '/account/registerkey');
    });

    test('carries the bootstrap cookies into the POST', () async {
      final api = _FakeApi(_successBody(), issued: {
        'steamCountry': 'CA%7Cxxxx',
        'browserid': '365505345981784514',
      });
      await StoreKeyClient(api).redeem(_account(), 'ABCDE');
      expect(api.cookies!['steamCountry'], 'CA%7Cxxxx');
      expect(api.cookies!['browserid'], '365505345981784514');
      expect(api.cookies!['steamLoginSecure'], '76561198000000123||tok');
    });

    test("a sessionid Steam issued beats the one we generated", () async {
      // The store is stricter than the community host, which only checks that
      // cookie and form field match — a self-minted id may simply be unknown.
      final api = _FakeApi(_successBody(), issued: {'sessionid': 'from-steam'});
      await StoreKeyClient(api).redeem(_account(), 'ABCDE');
      expect(api.form!['sessionid'], 'from-steam');
      expect(api.cookies!['sessionid'], 'from-steam');
    });

    test('the store cookie set carries no mobileClient marker', () {
      // The store serves a stripped mobile-app layout to that marker and its
      // ajax endpoints are not part of it.
      final jar = storeCookies(_account(), sessionId: 'abc');
      expect(jar.containsKey('mobileClient'), isFalse);
      expect(jar.keys.toSet(), {'steamLoginSecure', 'sessionid'});
    });

    test('a session with no access token fails before the key is sent',
        () async {
      // Sending it with an empty token would burn a one-use key on a request
      // Steam is going to reject anyway.
      final api = _FakeApi(_successBody());
      await expectLater(
        StoreKeyClient(api).redeem(_account(accessToken: null), 'ABCDE'),
        throwsA(isA<MissingAccessTokenException>()),
      );
      expect(api.calls, 0);
    });
  });
}
