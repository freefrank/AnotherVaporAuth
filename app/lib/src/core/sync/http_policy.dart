/// Transport-security policy for sync servers: which hosts may be reached
/// over plain HTTP.
///
/// The rule (2026-08-12, user decision, see the sync spec): public hosts must
/// use HTTPS by default; literal private hosts may use HTTP after a warning;
/// a public host over HTTP requires an explicit per-server override.
///
/// Classification looks ONLY at the literal host the user typed — never at
/// DNS results. A public domain that happens to resolve to a private address
/// still counts as public: resolution can change under an approved config,
/// silently turning "LAN-only" into plaintext across the open internet.
library;

import 'dart:io';

enum HttpHostClass {
  /// localhost / 127.0.0.0/8 / ::1 — same machine.
  loopback,

  /// A literal RFC 1918 / link-local / ULA address.
  privateLiteral,

  /// An mDNS `*.local` name (never resolves across the public internet).
  mdnsLocal,

  /// Everything else — including public domains that resolve privately.
  public,
}

HttpHostClass classifyHost(String host) {
  final h = host.toLowerCase().trim();
  if (h == 'localhost') return HttpHostClass.loopback;
  if (h.endsWith('.local')) return HttpHostClass.mdnsLocal;

  final ip = InternetAddress.tryParse(_stripBrackets(h));
  if (ip == null) return HttpHostClass.public;
  if (ip.isLoopback) return HttpHostClass.loopback;
  if (_isPrivate(ip)) return HttpHostClass.privateLiteral;
  return HttpHostClass.public;
}

/// Whether plain HTTP to [host] is acceptable given the per-server
/// [overrides] (hosts the user explicitly allowed after the long-press
/// warning). HTTPS is always acceptable — callers check the scheme first.
bool httpAllowedFor(String host, {required Set<String> overrides}) {
  if (overrides.contains(host.toLowerCase().trim())) return true;
  return classifyHost(host) != HttpHostClass.public;
}

/// Whether HTTP to [host] needs the private-network warning (as opposed to
/// the public-network override): true for every non-public class.
bool isPrivateHost(String host) => classifyHost(host) != HttpHostClass.public;

String _stripBrackets(String host) =>
    host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;

bool _isPrivate(InternetAddress ip) {
  final raw = ip.rawAddress;
  if (ip.type == InternetAddressType.IPv4) {
    final a = raw[0], b = raw[1];
    if (a == 10) return true; // 10.0.0.0/8
    if (a == 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
    if (a == 192 && b == 168) return true; // 192.168.0.0/16
    if (a == 169 && b == 254) return true; // 169.254.0.0/16 link-local
    return false;
  }
  // IPv6: fc00::/7 (ULA), fe80::/10 (link-local).
  final a = raw[0];
  if ((a & 0xfe) == 0xfc) return true;
  if (a == 0xfe && (raw[1] & 0xc0) == 0x80) return true;
  // IPv4-mapped (::ffff:a.b.c.d) — classify by the embedded IPv4.
  if (raw.length == 16 &&
      raw.sublist(0, 10).every((x) => x == 0) &&
      raw[10] == 0xff &&
      raw[11] == 0xff) {
    final v4 = raw.sublist(12);
    final a4 = v4[0], b4 = v4[1];
    if (a4 == 10) return true;
    if (a4 == 172 && b4 >= 16 && b4 <= 31) return true;
    if (a4 == 192 && b4 == 168) return true;
    if (a4 == 169 && b4 == 254) return true;
  }
  return false;
}
