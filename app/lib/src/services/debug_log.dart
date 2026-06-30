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
    final line = '$ts  $message';
    _lines.add(line);
    if (_lines.length > _max) _lines.removeRange(0, _lines.length - _max);
    if (kDebugMode) debugPrint(line);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  String dump() => _lines.join('\n');
}

/// Convenience top-level logger.
void dlog(String message) => DebugLog.instance.log(message);
