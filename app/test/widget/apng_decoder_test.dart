import 'dart:io';
import 'package:ava/src/ui/widgets/apng_decoder.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composites the Steam avatar-frame APNG into consistent full frames', () {
    final path = 'test/fixtures/apng_avatar_frame.png';
    final bytes = File(path).readAsBytesSync();
    final frames = decodeApngFrames(bytes)!;
    expect(frames.length, 60);
    for (var i = 0; i < frames.length; i++) {
      final im = frames[i].image;
      // Every composited frame must be full canvas AND its pixel buffer must
      // match its dimensions (the exact invariant the image package broke).
      expect(im.width, 224, reason: 'frame $i width');
      expect(im.height, 224, reason: 'frame $i height');
      final rgba = im.getBytes(order: img.ChannelOrder.rgba);
      expect(rgba.length ~/ 4, 224 * 224, reason: 'frame $i buffer size');
      expect(frames[i].delayMs, greaterThan(0));
      // The frame is a ring with a transparent centre — the palette + tRNS
      // must survive per-frame rebuild, so it must NOT come out fully opaque.
      var sumA = 0;
      for (var p = 3; p < rgba.length; p += 4) {
        sumA += rgba[p];
      }
      final avgA = sumA / (224 * 224);
      expect(avgA, lessThan(128), reason: 'frame $i should be mostly transparent');
      expect(avgA, greaterThan(1), reason: 'frame $i should not be fully blank');
    }
  });

  test('returns null for a non-animated PNG', () {
    final im = img.Image(width: 8, height: 8, numChannels: 4);
    final png = img.encodePng(im);
    expect(decodeApngFrames(png), isNull);
  });
}
