/// Lenient int coercion for Steam's JSON, which serializes the same field as
/// an int, a double, or a decimal string depending on endpoint and value size.
///
/// One shared definition instead of the nine per-model `_asInt` copies that
/// used to drift apart (trimmed vs untrimmed strings, fallback vs 0).
library;

/// [v] as an int, or [fallback] when it can't be read as one.
///
/// Accepts `int` verbatim, truncates other `num`s, and parses trimmed
/// strings; everything else (null, bool, maps…) yields [fallback].
int asInt(dynamic v, {int fallback = 0}) => asIntOrNull(v) ?? fallback;

/// [v] as an int, or null when it can't be read as one (same coercions as
/// [asInt], for callers that need "absent" kept distinct from a real 0).
int? asIntOrNull(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
