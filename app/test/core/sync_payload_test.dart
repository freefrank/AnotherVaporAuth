import 'dart:convert';

import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/sync/http_policy.dart';
import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:flutter_test/flutter_test.dart';

SteamGuardAccount account({
  int steamId = 76561198000000001,
  String? password = 'hunter2hunter2',
}) =>
    SteamGuardAccount.fromJson({
      'shared_secret': 'c2VjcmV0',
      'identity_secret': 'aWRlbnRpdHk=',
      'account_name': 'gaben',
      'revocation_code': 'R12345',
      'password': ?password,
      'Session': {
        'SteamID': steamId,
        'AccessToken': 'tokenA',
        'RefreshToken': 'tokenR',
      },
    });

void main() {
  group('syncPayloadJson', () {
    test('keeps the SteamID but never the session tokens', () {
      final payload = syncPayloadJson(account(), includePassword: true);
      final session = payload['Session'] as Map<String, dynamic>;
      expect(session['SteamID'], 76561198000000001);
      expect(session.containsKey('AccessToken'), isFalse);
      expect(session.containsKey('RefreshToken'), isFalse);
    });

    test('round-trips through the account model without minting a '
        'synthetic id', () {
      final payload = syncPayloadJson(account(), includePassword: true);
      final reparsed = SteamGuardAccount.fromJson(
          jsonDecode(jsonEncode(payload)) as Map<String, dynamic>);
      expect(reparsed.steamId, 76561198000000001);
      expect(reparsed.sharedSecret, 'c2VjcmV0');
      expect(reparsed.password, 'hunter2hunter2');
      expect(reparsed.session.hasTokens, isFalse);
    });

    test('include-password switch actually removes the password', () {
      final without = syncPayloadJson(account(), includePassword: false);
      expect(without.containsKey('password'), isFalse);
      final with_ = syncPayloadJson(account(), includePassword: true);
      expect(with_['password'], 'hunter2hunter2');
    });
  });

  group('payloadHash', () {
    test('is insensitive to key order', () {
      expect(
        payloadHash({'b': 1, 'a': {'y': 2, 'x': 3}}),
        payloadHash({'a': {'x': 3, 'y': 2}, 'b': 1}),
      );
    });

    test('differs when content differs', () {
      expect(payloadHash({'a': 1}), isNot(payloadHash({'a': 2})));
    });

    test('session tokens do not move the hash', () {
      final a = account();
      final h1 = payloadHash(syncPayloadJson(a, includePassword: true));
      a.session.accessToken = 'rotated';
      a.session.refreshToken = 'rotated-too';
      final h2 = payloadHash(syncPayloadJson(a, includePassword: true));
      expect(h1, h2);
    });
  });

  group('encrypt / decrypt round-trip', () {
    test('round-trips and rejects a wrong passphrase', () {
      final payload = syncPayloadJson(account(), includePassword: true);
      final enc = encryptSyncPayload('correct horse battery', payload);
      final back = decryptSyncPayload(
          'correct horse battery', enc.salt, enc.iv, enc.ciphertext);
      expect(back, isNotNull);
      expect(back!['account_name'], 'gaben');
      expect(
        decryptSyncPayload(
            'wrong passphrase!', enc.salt, enc.iv, enc.ciphertext),
        isNull,
      );
    });
  });

  group('passkey check token', () {
    test('verifies the right passphrase and rejects the wrong one', () {
      final token = buildPasskeyCheck('correct horse battery');
      expect(verifyPasskeyCheck('correct horse battery', token), isTrue);
      expect(verifyPasskeyCheck('wrong', token), isFalse);
    });

    test('is null (undecidable) on a missing or malformed token', () {
      expect(verifyPasskeyCheck('x', null), isNull);
      expect(verifyPasskeyCheck('x', 'not-a-token'), isNull);
    });
  });

  group('remote manifest', () {
    test('is a valid SDA-shaped manifest with per-entry crypto params', () {
      final text = buildRemoteManifest({
        76561198000000001: const SyncRemoteAccount(
          rev: 3,
          hash: 'h',
          filename: '76561198000000001.r3.ab12.maFile',
          salt: 'c2FsdA==',
          iv: 'aXZpdml2aXZpdml2aQ==',
        ),
      }, 'salt|iv|ct');
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json['encrypted'], isTrue);
      final entry = (json['entries'] as List).single as Map<String, dynamic>;
      expect(entry['steamid'], 76561198000000001);
      expect(entry['filename'], '76561198000000001.r3.ab12.maFile');
      expect(entry['encryption_salt'], 'c2FsdA==');
      expect(entry['encryption_iv'], 'aXZpdml2aXZpdml2aQ==');
      expect(json['passkey_check'], 'salt|iv|ct');
    });
  });

  group('sidecar serialization', () {
    test('round-trips accounts, tombstones, devices and flags', () {
      final sidecar = SyncSidecar(
        passphraseEpoch: 3,
        includePasswords: false,
        passkeyCheck: 's|i|c',
        accounts: {
          1: const SyncRemoteAccount(
              rev: 2, hash: 'h', filename: 'f', salt: 's', iv: 'i'),
        },
        tombstones: {
          2: const SyncTombstone(rev: 5, deletedAt: 't', device: 'd'),
        },
        devices: {
          'dev1': const SyncDeviceInfo(name: 'laptop', lastSyncAt: 'now'),
        },
      );
      final back = SyncSidecar.parse(sidecar.serialize());
      expect(back.passphraseEpoch, 3);
      expect(back.includePasswords, isFalse);
      expect(back.passkeyCheck, 's|i|c');
      expect(back.accounts[1]!.rev, 2);
      expect(back.tombstones[2]!.rev, 5);
      expect(back.devices['dev1']!.name, 'laptop');
    });
  });

  group('http policy', () {
    test('classifies literal hosts', () {
      expect(classifyHost('localhost'), HttpHostClass.loopback);
      expect(classifyHost('127.0.0.1'), HttpHostClass.loopback);
      expect(classifyHost('::1'), HttpHostClass.loopback);
      expect(classifyHost('10.0.0.5'), HttpHostClass.privateLiteral);
      expect(classifyHost('172.16.1.1'), HttpHostClass.privateLiteral);
      expect(classifyHost('172.32.1.1'), HttpHostClass.public);
      expect(classifyHost('192.168.1.83'), HttpHostClass.privateLiteral);
      expect(classifyHost('169.254.1.1'), HttpHostClass.privateLiteral);
      expect(classifyHost('fd00::1'), HttpHostClass.privateLiteral);
      expect(classifyHost('fe80::1'), HttpHostClass.privateLiteral);
      expect(classifyHost('nas.local'), HttpHostClass.mdnsLocal);
      expect(classifyHost('example.com'), HttpHostClass.public);
      expect(classifyHost('8.8.8.8'), HttpHostClass.public);
    });

    test('a public DOMAIN is public even if it would resolve privately',
        () {
      // The rule from the spec: classification looks only at the literal.
      expect(classifyHost('internal.corp.example.com'), HttpHostClass.public);
    });

    test('override set admits a public host, nothing else does', () {
      expect(httpAllowedFor('example.com', overrides: {}), isFalse);
      expect(
          httpAllowedFor('example.com', overrides: {'example.com'}), isTrue);
      expect(httpAllowedFor('192.168.1.83', overrides: {}), isTrue);
    });
  });
}
