import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sda/src/core/models/manifest.dart';
import 'package:sda/src/core/models/steam_guard_account.dart';

void main() {
  group('SteamGuardAccount JSON', () {
    test('lossless round trip preserving unknown keys', () {
      const raw = '''
      {
        "shared_secret": "c2hhcmVk",
        "serial_number": "123",
        "revocation_code": "R12345",
        "uri": "otpauth://totp/Steam",
        "server_time": 1700000000,
        "account_name": "tester",
        "token_gid": "abc",
        "identity_secret": "aWRlbnRpdHk=",
        "secret_1": "czE=",
        "status": 1,
        "device_id": "android:xyz",
        "fully_enrolled": true,
        "legacy_unknown_field": "keep-me",
        "Session": {
          "SteamID": 76561190000000000,
          "AccessToken": "atok",
          "RefreshToken": "rtok",
          "WebCookie": "legacy-cookie"
        }
      }
      ''';
      final acc =
          SteamGuardAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(acc.sharedSecret, 'c2hhcmVk');
      expect(acc.accountName, 'tester');
      expect(acc.fullyEnrolled, isTrue);
      expect(acc.steamId, 76561190000000000);
      expect(acc.session.accessToken, 'atok');

      final out = acc.toJson();
      // unknown top-level key preserved
      expect(out['legacy_unknown_field'], 'keep-me');
      // unknown session key preserved
      expect((out['Session'] as Map)['WebCookie'], 'legacy-cookie');
      // known fields intact
      expect(out['shared_secret'], 'c2hhcmVk');
      expect((out['Session'] as Map)['SteamID'], 76561190000000000);
    });

    test('tolerates string SteamID', () {
      final acc = SteamGuardAccount.fromJson({
        'Session': {'SteamID': '76561190000000001'},
      });
      expect(acc.steamId, 76561190000000001);
    });
  });

  group('Manifest JSON', () {
    test('round trips with field names matching the .NET version', () {
      const raw = '''
      {
        "encrypted": true,
        "first_run": false,
        "entries": [
          {
            "encryption_iv": "aXY=",
            "encryption_salt": "c2FsdA==",
            "filename": "76561190000000000.maFile",
            "steamid": 76561190000000000
          }
        ],
        "periodic_checking": true,
        "periodic_checking_interval": 10,
        "periodic_checking_checkall": true,
        "auto_confirm_market_transactions": true,
        "auto_confirm_trades": false
      }
      ''';
      final man = Manifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(man.encrypted, isTrue);
      expect(man.entries.length, 1);
      expect(man.entries.first.filename, '76561190000000000.maFile');
      expect(man.periodicCheckingInterval, 10);

      final out = man.toJson();
      expect(out['periodic_checking_checkall'], true);
      expect(out['auto_confirm_market_transactions'], true);
      expect((out['entries'] as List).first['steamid'], 76561190000000000);
    });

    test('defaults match the .NET new-manifest defaults', () {
      final man = Manifest();
      expect(man.encrypted, isFalse);
      expect(man.firstRun, isTrue);
      expect(man.periodicChecking, isFalse);
      expect(man.periodicCheckingInterval, 5);
    });
  });
}
