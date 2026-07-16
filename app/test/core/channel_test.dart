import 'package:ava/src/core/channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAvaChannel', () {
    test('play resolves to play', () {
      expect(parseAvaChannel('play'), AvaChannel.play);
    });

    test('cn resolves to cn', () {
      expect(parseAvaChannel('cn'), AvaChannel.cn);
    });

    test('unknown and empty values fall back to cn', () {
      expect(parseAvaChannel(''), AvaChannel.cn);
      expect(parseAvaChannel('PLAY'), AvaChannel.cn);
      expect(parseAvaChannel('desktop'), AvaChannel.cn);
    });
  });

  test('avaChannel defaults to cn when no dart-define is set', () {
    // The test runner passes no AVA_CHANNEL, exercising the fail-safe default.
    expect(avaChannel, AvaChannel.cn);
  });
}
