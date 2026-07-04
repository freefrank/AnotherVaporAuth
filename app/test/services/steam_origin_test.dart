import 'dart:typed_data';

import 'package:ava/src/services/steam_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns an empty 200 for any request, so accept-path tests never touch the
/// network.
class _OkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('', 200);
}

void main() {
  group('communityGetText initial-URL origin gate', () {
    SteamApiClient client() {
      final dio = Dio()..httpClientAdapter = _OkAdapter();
      return SteamApiClient(dio: dio);
    }

    test('rejects an absolute non-Steam URL without sending a request', () {
      expect(() => client().communityGetText('https://evil.example/steal'),
          throwsArgumentError);
    });

    test('rejects an absolute non-HTTPS Steam look-alike', () {
      expect(() => client().communityGetText('http://steamcommunity.com/x'),
          throwsArgumentError);
    });

    test('rejects an absolute suffix look-alike host', () {
      expect(
          () => client()
              .communityGetText('https://steamcommunity.com.evil.example/x'),
          throwsArgumentError);
    });

    test('accepts a relative path and an absolute Steam-origin URL', () async {
      await client().communityGetText('/mobileconf/getlist');
      await client()
          .communityGetText('https://steamcommunity.com/mobileconf/getlist');
    });
  });

  group('SteamApiClient.isSteamOrigin', () {
    test('accepts Steam HTTPS origins', () {
      for (final ok in [
        'https://steamcommunity.com/market/',
        'https://steamcommunity.com/profiles/1/inventory/',
        'https://store.steampowered.com/x',
        'https://help.steampowered.com/x',
        'https://login.steampowered.com/x',
        'https://api.steampowered.com/x',
        'https://cdn.steamcommunity.com/x',
      ]) {
        expect(SteamApiClient.isSteamOrigin(ok), isTrue, reason: ok);
      }
    });

    test('rejects non-Steam hosts, look-alikes, and non-HTTPS', () {
      for (final no in [
        'https://evil.example/x',
        'http://steamcommunity.com/x', // not https
        'https://steamcommunity.com.evil.example/x', // suffix look-alike
        'https://notsteamcommunity.com/x',
        'https://steampowered.com.attacker.net/x',
        'http://evil.example/steamLoginSecure',
        'ftp://steamcommunity.com/x',
        'javascript:alert(1)',
        '//steamcommunity.com/x', // no scheme
        '',
      ]) {
        expect(SteamApiClient.isSteamOrigin(no), isFalse, reason: no);
      }
    });
  });
}
