import 'package:flutter/foundation.dart';

/// A tiny in-app log so networked flows can be debugged on a real device
/// without `flutter run` / adb. Holds the most recent lines in a ring buffer.
class DebugLog extends ChangeNotifier {
  DebugLog._();
  static final DebugLog instance = DebugLog._();

  static const int _max = 400;
  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  void log(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final line = '$ts  ${redactSecrets(message)}';
    _lines.add(line);
    if (_lines.length > _max) _lines.removeRange(0, _lines.length - _max);
    if (kDebugMode) debugPrint(line);
    notifyListeners();
  }

  /// Defence-in-depth for the opt-in "attach debug log" feedback path: even
  /// though current call sites avoid logging secrets, a future `dlog` that
  /// slips in a token / cookie / secret would otherwise be mailed to the
  /// developer inbox. Masks the values of known-sensitive keys and long
  /// token-shaped blobs while leaving the surrounding message readable.
  static String redactSecrets(String input) {
    var out = input;
    // key=value / key: value / "key":"value" for sensitive key names.
    out = out.replaceAllMapped(
      RegExp(
        r'''(access_token|refresh_token|steamLoginSecure|shared_secret|identity_secret|secret_1|password|passwd|sessionid|token)("?\s*[:=]\s*"?)([^\s"&,;}]+)''',
        caseSensitive: false,
      ),
      (m) => '${m[1]}${m[2]}<redacted>',
    );
    // Bare long token-shaped blobs (>= 24 chars): base64url / hex / JWT-ish.
    // Excludes '/' so URL paths (e.g. Iface/Method) aren't mistaken for keys.
    out = out.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9+_-]{24,}={0,2}\b'),
      (m) => '<redacted:${m[0]!.length}>',
    );
    return out;
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  String dump() => _lines.join('\n');
}

/// Convenience top-level logger.
void dlog(String message) => DebugLog.instance.log(message);
