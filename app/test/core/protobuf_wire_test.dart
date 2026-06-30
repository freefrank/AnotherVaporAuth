import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';

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
        ..writeString(1, 'SDA')
        ..writeVarint(2, 1);
      final outer = ProtoWriter()..writeMessage(9, inner);

      final outerFields = ProtoReader(outer.toBytes()).parse();
      final innerFields = ProtoReader(outerFields[9]!.bytes!).parse();
      expect(innerFields[1]!.asString, 'SDA');
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
}
