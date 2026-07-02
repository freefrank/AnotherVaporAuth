import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/services/image_disk_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  int hits = 0;
  Uint8List? Function(String url) onGet;
  _FakeAdapter(this.onGet);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    hits++;
    final bytes = onGet(options.uri.toString());
    if (bytes == null) return ResponseBody.fromBytes(Uint8List(0), 404);
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tmp;
  late _FakeAdapter adapter;

  DiskImageCache cache() {
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
    dio.httpClientAdapter = adapter;
    return DiskImageCache(dio: dio, baseDir: () async => tmp);
  }

  final png = Uint8List.fromList(List.generate(64, (i) => i));
  const url = 'https://cdn.example/avatars/ab/abcdef_full.jpg';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ava_img_cache_test');
    adapter = _FakeAdapter((_) => png);
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('downloads once, then serves from disk across instances', () async {
    final a = cache();
    expect(await a.load(url), equals(png));
    expect(adapter.hits, 1);

    // A fresh instance (≈ app relaunch) must not touch the network.
    final b = cache();
    expect(await b.load(url), equals(png));
    expect(adapter.hits, 1);
  });

  test('serves the cached copy when the network is down', () async {
    await cache().load(url);
    adapter.onGet = (_) => throw const SocketException('offline');
    expect(await cache().load(url), equals(png));
  });

  test('a failed download returns null, writes nothing, and can retry',
      () async {
    adapter.onGet = (_) => null; // 404
    final c = cache();
    expect(await c.load(url), isNull);
    expect(tmp.listSync().whereType<File>(), isEmpty);

    adapter.onGet = (_) => png; // back online
    expect(await c.load(url), equals(png));
    expect(adapter.hits, 2);
  });

  test('evict forces a redownload', () async {
    final c = cache();
    await c.load(url);
    await c.evict(url);
    expect(await c.load(url), equals(png));
    expect(adapter.hits, 2);
  });

  test('concurrent loads of one URL share a single download', () async {
    final c = cache();
    final results = await Future.wait([c.load(url), c.load(url), c.load(url)]);
    expect(results, everyElement(equals(png)));
    expect(adapter.hits, 1);
  });

  test('prune drops stale entries and leftover tmp files, keeps fresh ones',
      () async {
    final c = cache();
    await c.load(url);

    final stale = File('${tmp.path}/stalehash');
    await stale.writeAsBytes(png);
    await stale.setLastModified(
        DateTime.now().subtract(const Duration(days: 90)));
    final torn = File('${tmp.path}/somehash.64.tmp');
    await torn.writeAsBytes([1, 2, 3]);

    await c.prune();

    expect(await stale.exists(), isFalse);
    expect(await torn.exists(), isFalse);
    expect(await c.load(url), equals(png)); // fresh entry survived
    expect(adapter.hits, 1);
  });
}
