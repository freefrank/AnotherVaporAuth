import 'package:ava/src/core/json_coerce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('asInt / asIntOrNull', () {
    // (input, coerced) — coerced == null means "not readable as an int".
    final cases = <(Object?, int?)>[
      (7, 7),
      (0, 0),
      (-3, -3),
      // SteamID64s exceed 2^53 — must survive as exact ints.
      (76561198000000123, 76561198000000123),
      (7.9, 7), // num.toInt() truncates
      (-7.9, -7),
      ('42', 42),
      ('-1', -1),
      (' 42 ', 42), // trimmed before parse (ma_file_normalizer heritage)
      ('76561198000000123', 76561198000000123),
      ('', null),
      ('abc', null),
      ('4.2', null), // int.tryParse rejects decimal strings
      (null, null),
      (true, null),
      (<String, dynamic>{}, null),
      (<int>[1], null),
    ];

    for (final (input, coerced) in cases) {
      test('asIntOrNull(${input is String ? "'$input'" : input})', () {
        expect(asIntOrNull(input), coerced);
      });

      test('asInt(${input is String ? "'$input'" : input})', () {
        expect(asInt(input), coerced ?? 0);
        expect(asInt(input, fallback: 99), coerced ?? 99);
      });
    }
  });
}
