import 'dart:convert';
import 'dart:typed_data';

/// Minimal protobuf wire-format reader/writer.
///
/// Only the wire types used by Steam's `IAuthenticationService` messages are
/// implemented: varint (0), 64-bit (1), length-delimited (2) and 32-bit (5).
/// This avoids a protoc dependency for a handful of small messages.
class ProtoWriter {
  final BytesBuilder _b = BytesBuilder();

  Uint8List toBytes() => _b.toBytes();

  void _tag(int field, int wire) => _varint((field << 3) | wire);

  void _varint(int value) {
    // Encode as 64-bit unsigned (handles negative ints as two's complement).
    var big = BigInt.from(value);
    if (big.isNegative) big = big.toUnsigned(64);
    final mask = BigInt.from(0x7f);
    final cont = BigInt.from(0x80);
    while (big > mask) {
      _b.addByte(((big & mask) | cont).toInt());
      big = big >> 7;
    }
    _b.addByte(big.toInt());
  }

  void writeVarint(int field, int value) {
    _tag(field, 0);
    _varint(value);
  }

  void writeBool(int field, bool value) => writeVarint(field, value ? 1 : 0);

  void writeUint64(int field, int value) => writeVarint(field, value);

  void writeString(int field, String value) {
    final bytes = utf8.encode(value);
    _tag(field, 2);
    _varint(bytes.length);
    _b.add(bytes);
  }

  void writeBytes(int field, List<int> value) {
    _tag(field, 2);
    _varint(value.length);
    _b.add(value);
  }

  void writeMessage(int field, ProtoWriter message) =>
      writeBytes(field, message.toBytes());

  /// 64-bit fixed (wire type 1), 8 bytes little-endian. Steam uses this for
  /// `steamid` in several messages (AddAuthenticator, mobile confirmation…).
  void writeFixed64(int field, int value) {
    _tag(field, 1);
    var big = BigInt.from(value);
    if (big.isNegative) big = big.toUnsigned(64);
    final mask = BigInt.from(0xff);
    for (var i = 0; i < 8; i++) {
      _b.addByte((big & mask).toInt());
      big = big >> 8;
    }
  }
}

class ProtoField {
  final int number;
  final int wireType;
  final int? varint; // for wire 0/1/5
  final Uint8List? bytes; // for wire 2
  ProtoField(this.number, this.wireType, {this.varint, this.bytes});

  String get asString => utf8.decode(bytes ?? const []);
  int get asInt => varint ?? 0;
  bool get asBool => (varint ?? 0) != 0;

  /// Reads a wire-type-1 (fixed64) field's 8 little-endian bytes as an int.
  int get asFixed64 {
    final b = bytes;
    if (b == null || b.length < 8) return 0;
    var big = BigInt.zero;
    for (var i = 7; i >= 0; i--) {
      big = (big << 8) | BigInt.from(b[i]);
    }
    if (big > BigInt.from(0x7fffffffffffffff)) return big.toSigned(64).toInt();
    return big.toInt();
  }
}

class ProtoReader {
  final Uint8List _data;
  int _pos = 0;
  ProtoReader(this._data);

  factory ProtoReader.fromBase64(String b64) =>
      ProtoReader(base64.decode(b64));

  bool get _hasMore => _pos < _data.length;

  int _readVarintRaw() {
    var shift = 0;
    var result = BigInt.zero;
    while (true) {
      final byte = _data[_pos++];
      result |= BigInt.from(byte & 0x7f) << shift;
      if (byte & 0x80 == 0) break;
      shift += 7;
    }
    // values fit in 64-bit; return as signed-safe int
    if (result > BigInt.from(0x7fffffffffffffff)) {
      return result.toSigned(64).toInt();
    }
    return result.toInt();
  }

  /// Parses all top-level fields into a map keyed by field number.
  /// Repeated fields keep their last occurrence here; use [parseAll] for repeats.
  Map<int, ProtoField> parse() {
    final out = <int, ProtoField>{};
    for (final f in parseAll()) {
      out[f.number] = f;
    }
    return out;
  }

  List<ProtoField> parseAll() {
    final out = <ProtoField>[];
    while (_hasMore) {
      final key = _readVarintRaw();
      final field = key >> 3;
      final wire = key & 0x7;
      switch (wire) {
        case 0:
          out.add(ProtoField(field, wire, varint: _readVarintRaw()));
          break;
        case 1:
          final v = _readFixed(8);
          out.add(ProtoField(field, wire, bytes: v));
          break;
        case 2:
          final len = _readVarintRaw();
          final b = Uint8List.sublistView(_data, _pos, _pos + len);
          _pos += len;
          out.add(ProtoField(field, wire, bytes: Uint8List.fromList(b)));
          break;
        case 5:
          final v = _readFixed(4);
          out.add(ProtoField(field, wire, bytes: v));
          break;
        default:
          throw FormatException('Unsupported wire type $wire');
      }
    }
    return out;
  }

  Uint8List _readFixed(int n) {
    final b = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return Uint8List.fromList(b);
  }
}
