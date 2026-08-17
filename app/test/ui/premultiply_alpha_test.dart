import 'package:ava/src/ui/widgets/animated_steam_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The engine uploads these buffers as [ui.PixelFormat.rgba8888], which is
/// premultiplied; `package:image` hands us straight alpha. Everything below
/// pins the conversion between the two.
void main() {
  group('premultiplyAlpha', () {
    test('zeroes the colour under fully transparent pixels', () {
      // Steam's avatar-frame PNGs store white beneath alpha 0. Left as-is,
      // the engine reads it as "full white at zero coverage" and paints the
      // frame's transparent middle as a solid white block over the avatar
      // (issue #3: the frame drew fine, the avatar vanished behind it).
      final im = img.Image(width: 2, height: 1, numChannels: 4);
      im.setPixelRgba(0, 0, 255, 255, 255, 0);
      im.setPixelRgba(1, 0, 12, 34, 56, 255);

      premultiplyAlpha(im);

      final clear = im.getPixel(0, 0);
      expect([clear.r, clear.g, clear.b, clear.a], [0, 0, 0, 0]);
      // An opaque pixel must come through untouched.
      final solid = im.getPixel(1, 0);
      expect([solid.r, solid.g, solid.b, solid.a], [12, 34, 56, 255]);
    });

    test('scales colour by alpha for semi-transparent pixels', () {
      final im = img.Image(width: 1, height: 1, numChannels: 4);
      im.setPixelRgba(0, 0, 255, 128, 0, 128);

      premultiplyAlpha(im);

      final p = im.getPixel(0, 0);
      expect(p.a, 128);
      expect(p.r, 128); // 255 * 128 / 255
      expect(p.g, 64); //  128 * 128 / 255, rounded
      expect(p.b, 0);
    });

    test('leaves no channel above its alpha — the premultiplied invariant',
        () {
      final im = img.Image(width: 256, height: 1, numChannels: 4);
      for (var a = 0; a < 256; a++) {
        im.setPixelRgba(a, 0, 255, 200, 100, a);
      }

      premultiplyAlpha(im);

      for (final p in im) {
        final a = p.a.toInt();
        expect(p.r.toInt(), lessThanOrEqualTo(a));
        expect(p.g.toInt(), lessThanOrEqualTo(a));
        expect(p.b.toInt(), lessThanOrEqualTo(a));
      }
    });

    test('promotes a palette image so alpha can be written back', () {
      // GIF avatars decode to palette images; setRgba on those would go
      // through the palette instead of the pixel buffer.
      final pal = img.PaletteUint8(2, 4);
      pal.setRgba(0, 255, 255, 255, 0); // white, fully transparent
      pal.setRgba(1, 10, 20, 30, 255);
      final im =
          img.Image(width: 2, height: 1, numChannels: 1, palette: pal);
      im.setPixelIndex(0, 0, 0);
      im.setPixelIndex(1, 0, 1);

      final out = premultiplyAlpha(im);

      expect(out.hasPalette, isFalse);
      final clear = out.getPixel(0, 0);
      expect([clear.r, clear.g, clear.b, clear.a], [0, 0, 0, 0]);
    });

    test('passes an image without an alpha channel straight through', () {
      final im = img.Image(width: 1, height: 1, numChannels: 3);
      im.setPixelRgb(0, 0, 255, 255, 255);

      final out = premultiplyAlpha(im);

      final p = out.getPixel(0, 0);
      expect([p.r, p.g, p.b], [255, 255, 255]);
    });
  });
}
