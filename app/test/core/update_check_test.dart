import 'package:ava/src/core/channel.dart';
import 'package:ava/src/core/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('numeric per segment, not lexicographic', () {
      // The classic trap: as strings, '1.10.0' < '1.9.0'.
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
    });

    test('equal, newer, older', () {
      expect(compareVersions('1.2.0', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2.0'), greaterThan(0));
      expect(compareVersions('1.2.0', '2.0.0'), lessThan(0));
    });

    test('missing segments read as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.3', '1.2.9'), greaterThan(0));
    });

    test('pre-release suffixes are ignored, not crashed on', () {
      expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
      expect(compareVersions('1.3.0-rc1', '1.2.0'), greaterThan(0));
    });
  });

  group('updateChannelKey', () {
    test('android splits by channel', () {
      expect(updateChannelKey(os: 'android', channel: AvaChannel.play), 'android-play');
      expect(updateChannelKey(os: 'android', channel: AvaChannel.cn), 'android-cn');
    });

    test('desktop maps per OS', () {
      expect(updateChannelKey(os: 'windows'), 'windows-setup');
      expect(updateChannelKey(os: 'linux'), 'linux-appimage');
      expect(updateChannelKey(os: 'macos'), 'macos-dmg');
    });

    test('anything else asks about a key that cannot exist', () {
      expect(updateChannelKey(os: 'fuchsia'), 'unknown');
    });
  });

  group('decideUpdate', () {
    Map<String, dynamic> table(String version) => {
          'windows-setup': {'version': version},
        };

    test('newer remote version is available', () {
      final d = decideUpdate(
        channels: table('1.3.0'),
        channelKey: 'windows-setup',
        currentVersion: '1.2.0',
      );
      expect(d.available, isTrue);
      expect(d.latest, '1.3.0');
    });

    test('same or older stays silent', () {
      for (final v in ['1.2.0', '1.1.9', '0.9.0']) {
        expect(
          decideUpdate(
            channels: table(v),
            channelKey: 'windows-setup',
            currentVersion: '1.2.0',
          ).available,
          isFalse,
          reason: v,
        );
      }
    });

    test('a dismissed version stays dismissed', () {
      final d = decideUpdate(
        channels: table('1.3.0'),
        channelKey: 'windows-setup',
        currentVersion: '1.2.0',
        dismissedVersion: '1.3.0',
      );
      expect(d.available, isFalse);
    });

    test('a dismissal does not cover the version after it', () {
      final d = decideUpdate(
        channels: table('1.4.0'),
        channelKey: 'windows-setup',
        currentVersion: '1.2.0',
        dismissedVersion: '1.3.0',
      );
      expect(d.available, isTrue);
    });

    test('absent key, malformed entry, and null table all degrade to silence',
        () {
      // A broken or hostile response must never produce a prompt.
      final cases = <Map<String, dynamic>?>[
        null,
        {},
        {'windows-setup': 'not-a-map'},
        {'windows-setup': {}},
        {
          'windows-setup': {'version': 7}
        },
        {
          'windows-setup': {'version': ''}
        },
      ];
      for (final c in cases) {
        expect(
          decideUpdate(
            channels: c,
            channelKey: 'windows-setup',
            currentVersion: '1.2.0',
          ).available,
          isFalse,
          reason: '$c',
        );
      }
    });
  });
}
