import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';

/// Parses [bytes], allowing only two outcomes: a clean parse or a
/// [ProtoParseException]. Any other throw (RangeError above all — the raw
/// string users used to see) fails the test.
void _parseNeverEscapes(Uint8List bytes) {
  try {
    ProtoReader(bytes).parseAll();
  } on ProtoParseException {
    // The one permitted failure mode.
  }
}

void main() {
  group('ProtoWriter/ProtoReader round trip', () {
    test('varint, bool, string', () {
      final w = ProtoWriter()
        ..writeVarint(1, 300)
        ..writeBool(2, true)
        ..writeString(3, 'hello');
      final fields = ProtoReader(w.toBytes()).parse();
      expect(fields[1]!.asInt, 300);
      expect(fields[2]!.asBool, isTrue);
      expect(fields[3]!.asString, 'hello');
    });

    test('large uint64 (client_id-like)', () {
      const big = 76561190000000000;
      final w = ProtoWriter()..writeUint64(1, big);
      final fields = ProtoReader(w.toBytes()).parse();
      expect(fields[1]!.asInt, big);
    });

    test('nested message', () {
      final inner = ProtoWriter()
        ..writeString(1, 'AVA')
        ..writeVarint(2, 1);
      final outer = ProtoWriter()..writeMessage(9, inner);

      final outerFields = ProtoReader(outer.toBytes()).parse();
      final innerFields = ProtoReader(outerFields[9]!.bytes!).parse();
      expect(innerFields[1]!.asString, 'AVA');
      expect(innerFields[2]!.asInt, 1);
    });

    test('repeated fields via parseAll', () {
      final w = ProtoWriter()
        ..writeString(4, 'a')
        ..writeString(4, 'b')
        ..writeString(4, 'c');
      final all = ProtoReader(w.toBytes())
          .parseAll()
          .where((f) => f.number == 4)
          .map((f) => f.asString)
          .toList();
      expect(all, ['a', 'b', 'c']);
    });

    test('bytes field', () {
      final w = ProtoWriter()..writeBytes(1, [0xDE, 0xAD, 0xBE, 0xEF]);
      final fields = ProtoReader(w.toBytes()).parse();
      expect(fields[1]!.bytes, [0xDE, 0xAD, 0xBE, 0xEF]);
    });

    test('fixed64 round trip (steamid)', () {
      const steamId = 76561198000000000; // < 2^63
      final w = ProtoWriter()..writeFixed64(3, steamId);
      final f = ProtoReader(w.toBytes()).parse()[3]!;
      expect(f.wireType, 1);
      expect(f.bytes!.length, 8);
      expect(f.asFixed64, steamId);
    });

    test('fixed64 large uint64 (> 2^63) round trip', () {
      // e.g. a client_id-like value above the signed range.
      const v = -524256132778200960; // stored signed; bytes are unsigned 64-bit
      final w = ProtoWriter()..writeFixed64(3, v);
      expect(ProtoReader(w.toBytes()).parse()[3]!.asFixed64, v);
    });
  });

  group('ProtoReader bounds checking', () {
    // One field of every implemented wire type, so truncation cuts through
    // varint, fixed64, length-delimited and fixed32 territory.
    Uint8List valid() => (ProtoWriter()
          ..writeVarint(1, 300)
          ..writeFixed64(2, 76561198000000000)
          ..writeString(3, 'hello')
          ..writeBytes(4, const [0xDE, 0xAD, 0xBE, 0xEF]))
        .toBytes();

    test('ProtoParseException is a FormatException (UI mapping contract)', () {
      expect(ProtoParseException('x'), isA<FormatException>());
    });

    test('truncation at every prefix length never escapes', () {
      final bytes = valid();
      for (var n = 0; n < bytes.length; n++) {
        _parseNeverEscapes(Uint8List.sublistView(bytes, 0, n));
      }
    });

    test('fuzz: 1k random byte strings never escape', () {
      // Seeded: a failing input must reproduce on re-run.
      final rng = Random(20260717);
      for (var i = 0; i < 1000; i++) {
        final len = rng.nextInt(64);
        _parseNeverEscapes(
          Uint8List.fromList(List.generate(len, (_) => rng.nextInt(256))),
        );
      }
    });

    test('varint cut mid-continuation throws ProtoParseException', () {
      // Field 1 wire 0, then a lone continuation byte.
      final bytes = Uint8List.fromList([0x08, 0x80]);
      expect(() => ProtoReader(bytes).parseAll(),
          throwsA(isA<ProtoParseException>()));
    });

    test('varint longer than 10 bytes throws ProtoParseException', () {
      final bytes = Uint8List.fromList([0x08, ...List.filled(11, 0x80), 0x01]);
      expect(() => ProtoReader(bytes).parseAll(),
          throwsA(isA<ProtoParseException>()));
    });

    test('wire-2 length one past remaining throws ProtoParseException', () {
      // Field 1 wire 2, len=2, only 1 payload byte present.
      final bytes = Uint8List.fromList([0x0A, 0x02, 0x61]);
      expect(() => ProtoReader(bytes).parseAll(),
          throwsA(isA<ProtoParseException>()));
    });

    test('wire-2 huge length (bit 63 set → negative) throws, not allocates',
        () {
      // len = 2^63: signed-reinterpreted to a negative int by the varint
      // reader — the guard must catch it rather than sublistView.
      final bytes =
          Uint8List.fromList([0x0A, ...List.filled(9, 0x80), 0x01, 0x61]);
      expect(() => ProtoReader(bytes).parseAll(),
          throwsA(isA<ProtoParseException>()));
    });

    test('fixed64 with 3 bytes left throws ProtoParseException', () {
      // Field 1 wire 1 needs 8 bytes.
      final bytes = Uint8List.fromList([0x09, 0x01, 0x02, 0x03]);
      expect(() => ProtoReader(bytes).parseAll(),
          throwsA(isA<ProtoParseException>()));
    });

    test('fixed32 with 2 bytes left throws ProtoParseException', () {
      // Field 1 wire 5 needs 4 bytes.
      final bytes = Uint8List.fromList([0x0D, 0x01, 0x02]);
      expect(() => ProtoReader(bytes).parseAll(),
          throwsA(isA<ProtoParseException>()));
    });
  });

  group('packed varint reader', () {
    test('readPackedVarints round-trips values incl. > 2^63', () {
      const a = 300;
      const b = 76561190000000000;
      const c = -524256132778200960; // an unsigned-64 client id, stored signed
      // Encode by writing tagged varints and stripping each 1-byte tag —
      // ProtoWriter has no packed writer, and hand-rolling one here would
      // just re-implement the code under test.
      final packed = BytesBuilder();
      for (final v in [a, b, c]) {
        final tagged = (ProtoWriter()..writeUint64(1, v)).toBytes();
        packed.add(tagged.sublist(1));
      }
      expect(ProtoReader.readPackedVarints(packed.toBytes()), [a, b, c]);
    });

    test('asPackedVarints decodes a wire-2 field payload', () {
      final w = ProtoWriter()..writeBytes(1, const [0x03, 0xAC, 0x02]);
      final f = ProtoReader(w.toBytes()).parse()[1]!;
      expect(f.asPackedVarints(), [3, 300]);
    });

    test('truncated packed payload throws instead of under-reading', () {
      expect(() => ProtoReader.readPackedVarints(Uint8List.fromList([0x80])),
          throwsA(isA<ProtoParseException>()));
    });

    test('empty payload decodes to an empty list', () {
      expect(ProtoReader.readPackedVarints(Uint8List(0)), isEmpty);
    });
  });
}
