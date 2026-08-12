/// Minimal WebDAV transport — exactly the verbs the sync engine needs (GET /
/// PUT / DELETE / MKCOL with conditional headers), nothing more.
///
/// Deliberately not a WebDAV *client*: there is no PROPFIND and no XML. The
/// engine always knows which files it wants — the sidecar names them — so
/// directory listing is never needed, and skipping it keeps this file free of
/// an XML dependency and of every server's PROPFIND quirks.
///
/// Built on dart:io HttpClient directly (not dio): certificate pinning needs
/// `badCertificateCallback`, and WebDAV needs the MKCOL verb — both are
/// first-class here and awkward through an adapter.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import '../../core/sync/http_policy.dart';
import '../../core/sync/sync_transport.dart';

class WebDavTransport implements SyncTransport {
  /// Remote folder URL, always with a trailing slash.
  final Uri baseUrl;
  final String username;
  final String password;

  /// Lowercase hex SHA-256 of a certificate DER the user pinned for this
  /// host (self-signed NAS). Null = system trust store only.
  final String? pinnedCertSha256;

  /// Hosts the user explicitly allowed to use plain HTTP despite being
  /// public (the risk-acknowledged override; private hosts need no entry).
  final Set<String> httpOverrides;

  final Duration timeout;

  final HttpClient _client;

  /// The fingerprint of the last certificate rejected by the pin check, so
  /// the HandshakeException can be turned into a [SyncTlsUntrusted] that
  /// carries what the UI needs to offer pinning.
  String? _lastRejectedFingerprint;

  WebDavTransport({
    required Uri url,
    required this.username,
    required this.password,
    this.pinnedCertSha256,
    this.httpOverrides = const {},
    this.timeout = const Duration(seconds: 20),
  })  : baseUrl = _normalize(url),
        _client = HttpClient() {
    if (baseUrl.scheme == 'http' &&
        !httpAllowedFor(baseUrl.host, overrides: httpOverrides)) {
      throw const SyncHttpPolicyError(
          'plain HTTP to a public host requires the per-server override');
    }
    if (baseUrl.scheme != 'http' && baseUrl.scheme != 'https') {
      throw const SyncHttpPolicyError('only http/https URLs are supported');
    }
    _client
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (cert, host, port) {
        final fp = sha256.convert(cert.der).toString();
        if (pinnedCertSha256 != null &&
            fp == pinnedCertSha256!.toLowerCase()) {
          return true;
        }
        _lastRejectedFingerprint = fp;
        return false;
      };
  }

  static Uri _normalize(Uri url) {
    var path = url.path;
    if (!path.endsWith('/')) path = '$path/';
    return url.replace(path: path, query: null, fragment: null);
  }

  @override
  void close() => _client.close(force: true);

  Uri _fileUrl(String name) =>
      baseUrl.replace(path: '${baseUrl.path}${Uri.encodeComponent(name)}');

  String get _basicAuth =>
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  Future<HttpClientResponse> _request(
    String method,
    Uri url, {
    Uint8List? body,
    Map<String, String> headers = const {},
  }) async {
    try {
      final req = await _client.openUrl(method, url).timeout(timeout);
      // No transparent redirects: a PUT that gets 301-ed and re-sent
      // elsewhere is how data ends up on the wrong host. The error path
      // below reports the redirect so the user fixes the URL instead.
      req.followRedirects = false;
      req.headers.set(HttpHeaders.authorizationHeader, _basicAuth);
      headers.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentLength = body.length;
        req.add(body);
      }
      return await req.close().timeout(timeout);
    } on HandshakeException {
      final fp = _lastRejectedFingerprint;
      if (fp != null) throw SyncTlsUntrusted(url.host, fp);
      rethrow;
    } on TimeoutException {
      throw const SyncNetworkError('connection timed out');
    } on SocketException catch (e) {
      throw SyncNetworkError(e.message.isEmpty ? 'network error' : e.message);
    } on HttpException catch (e) {
      throw SyncNetworkError(e.message);
    }
  }

  Future<Uint8List> _drain(HttpClientResponse res) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Never _fail(HttpClientResponse res, String what) {
    final s = res.statusCode;
    if (s == 401 || s == 403) {
      throw SyncAuthError('$what: server rejected the credentials ($s)');
    }
    if (s == 412) {
      throw SyncPreconditionFailed('$what: lost the commit race (412)');
    }
    if (s >= 300 && s < 400) {
      final loc = res.headers.value(HttpHeaders.locationHeader) ?? '?';
      throw SyncServerError(
          s, '$what: server redirects to $loc — use that URL directly');
    }
    throw SyncServerError(s, '$what: HTTP $s');
  }

  @override
  Future<void> probe() async {
    // A GET of the sidecar answers everything the wizard asks: DNS/TLS/auth
    // all run, and both 200 and 404 mean "server fine". MKCOL/PUT come later.
    final res = await _request('GET', _fileUrl('ava.sync.json'));
    await _drain(res);
    if (res.statusCode == 200 || res.statusCode == 404) return;
    _fail(res, 'probe');
  }

  @override
  Future<void> ensureRoot() => _ensureCollection(baseUrl, budget: 8);

  /// MKCOL with missing-parent recovery: a 409 means an ancestor collection
  /// does not exist, so create upward first, then retry. [budget] bounds the
  /// total MKCOL count — a URL whose ancestors can never be created (server
  /// roots answer 403/405 and stop the walk anyway) must not loop.
  Future<void> _ensureCollection(Uri url, {required int budget}) async {
    final res = await _request('MKCOL', url);
    await _drain(res);
    switch (res.statusCode) {
      case 201: // created
      case 405: // already exists
        return;
      case 409:
        final segments =
            url.pathSegments.where((s) => s.isNotEmpty).toList();
        if (budget <= 0 || segments.length <= 1) {
          throw const SyncServerError(
              409,
              'parent folder does not exist on the server — '
              'create the path first');
        }
        final parent = url.replace(
            pathSegments: [...segments.sublist(0, segments.length - 1), '']);
        await _ensureCollection(parent, budget: budget - 1);
        return _ensureCollection(url, budget: budget - 1);
      default:
        _fail(res, 'create folder');
    }
  }

  @override
  Future<RemoteFile?> getFile(String name) async {
    final res = await _request('GET', _fileUrl(name));
    if (res.statusCode == 404) {
      await _drain(res);
      return null;
    }
    if (res.statusCode != 200) {
      await _drain(res);
      _fail(res, 'download $name');
    }
    final bytes = await _drain(res);
    return RemoteFile(bytes, res.headers.value(HttpHeaders.etagHeader));
  }

  @override
  Future<String?> putFile(String name, Uint8List bytes,
      {String? ifMatch, bool ifAbsent = false}) async {
    assert(ifMatch == null || !ifAbsent);
    final res = await _request(
      'PUT',
      _fileUrl(name),
      body: bytes,
      headers: {
        'Content-Type': 'application/octet-stream',
        'If-Match': ?ifMatch,
        if (ifAbsent) 'If-None-Match': '*',
      },
    );
    await _drain(res);
    if (res.statusCode == 200 || res.statusCode == 201 ||
        res.statusCode == 204) {
      return res.headers.value(HttpHeaders.etagHeader);
    }
    _fail(res, 'upload $name');
  }

  @override
  Future<void> deleteFile(String name) async {
    final res = await _request('DELETE', _fileUrl(name));
    await _drain(res);
    if (res.statusCode == 200 ||
        res.statusCode == 204 ||
        res.statusCode == 404) {
      return;
    }
    _fail(res, 'delete $name');
  }

  @override
  Future<bool> checkConditionalSupport() async {
    // Create a probe file, then try to create it again with If-None-Match: *.
    // A server that enforces conditionals answers 412; one that ignores them
    // answers 2xx — which silently downgrades the engine's optimistic lock,
    // so the caller records it and warns.
    const name = 'ava.sync.probe.tmp';
    final payload = Uint8List.fromList(utf8.encode('probe'));
    try {
      await putFile(name, payload);
      try {
        await putFile(name, payload, ifAbsent: true);
        return false; // second create succeeded → conditionals ignored
      } on SyncPreconditionFailed {
        return true;
      }
    } finally {
      try {
        await deleteFile(name);
      } catch (_) {/* best-effort cleanup */}
    }
  }
}
