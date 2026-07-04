import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One fully-composited APNG frame (full canvas size) plus its display delay.
class ApngFrame {
  final img.Image image;
  final int delayMs;
  ApngFrame(this.image, this.delayMs);
}

/// Decodes an APNG into fully-composited full-canvas frames.
///
/// The `image` package (4.9.1) returns APNG sub-frames with their declared
/// canvas dimensions but a smaller pixel buffer, and exposes no per-frame
/// offset / dispose / blend — so rendering those "frames" directly shows a
/// stretched partial region and the image flickers. This parses the APNG
/// chunks itself (acTL / fcTL / fdAT) and composites each region onto a
/// running canvas per the APNG spec.
///
/// Returns null when [bytes] is not an animated PNG (no `acTL`), so the caller
/// can fall through to the plain single-image / GIF path.
List<ApngFrame>? decodeApngFrames(Uint8List bytes) {
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 8) return null;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != sig[i]) return null;
  }
  final data = ByteData.sublistView(bytes);

  Uint8List? ihdr; // 13-byte IHDR payload
  Uint8List? plte; // palette (colour type 3)
  Uint8List? trns; // palette transparency
  var canvasW = 0, canvasH = 0;
  var isAnimated = false;

  // Frame accumulators.
  final fctls = <_Fctl>[];
  final frameData = <List<Uint8List>>[]; // deflate chunks per frame
  var sawIdat = false;
  var idatBelongsToFrame0 = false;

  var pos = 8;
  while (pos + 8 <= bytes.length) {
    final len = data.getUint32(pos);
    final type = String.fromCharCodes(bytes, pos + 4, pos + 8);
    final payloadStart = pos + 8;
    final payloadEnd = payloadStart + len;
    if (payloadEnd + 4 > bytes.length) break;
    final payload = Uint8List.sublistView(bytes, payloadStart, payloadEnd);

    switch (type) {
      case 'IHDR':
        ihdr = Uint8List.fromList(payload);
        canvasW = data.getUint32(payloadStart);
        canvasH = data.getUint32(payloadStart + 4);
        break;
      case 'acTL':
        isAnimated = true;
        break;
      case 'PLTE':
        plte = Uint8List.fromList(payload);
        break;
      case 'tRNS':
        trns = Uint8List.fromList(payload);
        break;
      case 'fcTL':
        fctls.add(_Fctl.parse(ByteData.sublistView(payload)));
        // A fcTL before the first IDAT means the default image is frame 0.
        if (!sawIdat) idatBelongsToFrame0 = true;
        frameData.add(<Uint8List>[]);
        break;
      case 'IDAT':
        sawIdat = true;
        if (idatBelongsToFrame0 && frameData.isNotEmpty) {
          frameData.first.add(payload);
        }
        break;
      case 'fdAT':
        // seq(4) + frame data; belongs to the most recent fcTL.
        if (frameData.isNotEmpty) {
          frameData.last.add(Uint8List.sublistView(payload, 4));
        }
        break;
      case 'IEND':
        pos = bytes.length; // stop
        break;
    }
    pos = payloadEnd + 4; // skip CRC
  }

  if (!isAnimated || ihdr == null || fctls.isEmpty || canvasW == 0) {
    return null;
  }

  final canvas =
      img.Image(width: canvasW, height: canvasH, numChannels: 4);
  final out = <ApngFrame>[];

  for (var k = 0; k < fctls.length; k++) {
    final fc = fctls[k];
    if (k >= frameData.length || frameData[k].isEmpty) continue;
    final subPng =
        _rebuildPng(ihdr, plte, trns, fc.width, fc.height, frameData[k]);
    final sub = img.decodeImage(subPng);
    if (sub == null) continue;

    img.Image? saved;
    if (fc.disposeOp == 2) saved = canvas.clone(); // DISPOSE_PREVIOUS

    img.compositeImage(canvas, sub,
        dstX: fc.xOffset,
        dstY: fc.yOffset,
        // blend 0 (SOURCE) overwrites the region incl. alpha; 1 (OVER) alpha-composites.
        blend: fc.blendOp == 0 ? img.BlendMode.direct : img.BlendMode.alpha);

    out.add(ApngFrame(canvas.clone(), fc.delayMs));

    // Dispose for the next frame.
    switch (fc.disposeOp) {
      case 1: // BACKGROUND: clear this region to transparent black.
        img.fillRect(canvas,
            x1: fc.xOffset,
            y1: fc.yOffset,
            x2: fc.xOffset + fc.width - 1,
            y2: fc.yOffset + fc.height - 1,
            color: img.ColorRgba8(0, 0, 0, 0));
        break;
      case 2: // PREVIOUS: restore the pre-frame canvas.
        if (saved != null) {
          img.compositeImage(canvas, saved, blend: img.BlendMode.direct);
        }
        break;
      // 0 NONE: leave the canvas as-is.
    }
  }

  return out.isEmpty ? null : out;
}

class _Fctl {
  final int width, height, xOffset, yOffset, delayMs, disposeOp, blendOp;
  _Fctl(this.width, this.height, this.xOffset, this.yOffset, this.delayMs,
      this.disposeOp, this.blendOp);

  factory _Fctl.parse(ByteData d) {
    // seq(4) width(4) height(4) xoff(4) yoff(4) delayNum(2) delayDen(2)
    // dispose(1) blend(1)
    final width = d.getUint32(4);
    final height = d.getUint32(8);
    final xOff = d.getUint32(12);
    final yOff = d.getUint32(16);
    final delayNum = d.getUint16(20);
    var delayDen = d.getUint16(22);
    if (delayDen == 0) delayDen = 100; // APNG: den 0 means 1/100 s
    final delayMs = (delayNum * 1000 / delayDen).round();
    return _Fctl(width, height, xOff, yOff, delayMs, d.getUint8(24),
        d.getUint8(25));
  }
}

/// Rebuilds a standalone single-frame PNG from the shared IHDR (with the
/// frame's own width/height) and the frame's concatenated deflate data.
Uint8List _rebuildPng(Uint8List ihdr, Uint8List? plte, Uint8List? trns,
    int width, int height, List<Uint8List> idatParts) {
  final b = BytesBuilder();
  b.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  // IHDR with the frame's dimensions (bytes 8.. keep bit-depth/colour/etc).
  final ih = Uint8List.fromList(ihdr);
  ByteData.sublistView(ih)
    ..setUint32(0, width)
    ..setUint32(4, height);
  _writeChunk(b, 'IHDR', ih);
  // Palette + its transparency must travel with every frame or a palette
  // (colour type 3) APNG decodes as opaque garbage.
  if (plte != null) _writeChunk(b, 'PLTE', plte);
  if (trns != null) _writeChunk(b, 'tRNS', trns);
  final idat = BytesBuilder();
  for (final p in idatParts) {
    idat.add(p);
  }
  _writeChunk(b, 'IDAT', idat.toBytes());
  _writeChunk(b, 'IEND', Uint8List(0));
  return b.toBytes();
}

void _writeChunk(BytesBuilder b, String type, Uint8List data) {
  final len = Uint8List(4);
  ByteData.sublistView(len).setUint32(0, data.length);
  b.add(len);
  final typeBytes = Uint8List.fromList(type.codeUnits);
  b.add(typeBytes);
  b.add(data);
  final crcInput = BytesBuilder()
    ..add(typeBytes)
    ..add(data);
  final crc = Uint8List(4);
  ByteData.sublistView(crc).setUint32(0, _crc32(crcInput.toBytes()));
  b.add(crc);
}

// Standard PNG CRC-32.
final Uint32List _crcTable = _buildCrcTable();
Uint32List _buildCrcTable() {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}

int _crc32(Uint8List data) {
  var c = 0xffffffff;
  for (final byte in data) {
    c = _crcTable[(c ^ byte) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}
