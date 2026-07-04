import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
