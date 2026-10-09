import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/services/sync/webdav_transport.dart';
import 'package:flutter_test/flutter_test.dart';

// Against a real local HTTP server standing in for a WebDAV origin behind a
// CDN: the CDN's on-the-fly compression downgrades the origin's strong ETag
// to W/"…", which no If-Match can ever satisfy.
void main() {
  late HttpServer server;
  late WebDavTransport transport;
  final seen = <String, Map<String, String?>>{};

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      seen[req.method] = {
        'accept-encoding':
            req.headers.value(HttpHeaders.acceptEncodingHeader),
        'if-match': req.headers.value(HttpHeaders.ifMatchHeader),
      };
      await req.drain<void>();
      if (req.method == 'GET') {
        req.response.headers.set(HttpHeaders.etagHeader, 'W/"5-63a1"');
        req.response.write('{"v":1}');
      } else {
        req.response.statusCode = HttpStatus.noContent;
      }
      await req.response.close();
    });
    transport = WebDavTransport(
      url: Uri.parse('http://127.0.0.1:${server.port}/dav/ava'),
      username: 'u',
      password: 'p',
    );
  });

  tearDown(() async {
    transport.close();
    await server.close(force: true);
  });

  test('downloads uncompressed and guards with the strong ETag', () async {
    final file = await transport.getFile('ava.sync.json');
    expect(seen['GET']!['accept-encoding'], 'identity');
    expect(file!.etag, '"5-63a1"');

    await transport.putFile('ava.sync.json', Uint8List(0),
        ifMatch: file.etag);
    expect(seen['PUT']!['if-match'], '"5-63a1"');
  });
}
