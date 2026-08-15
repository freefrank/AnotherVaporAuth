/// Update-check decisions (v1.3, step one of
/// docs/plans/2026-08-14-update-checker.md): who am I, is the answer newer,
/// and nothing else. No network and no Flutter in this file — the fetch lives
/// in the service layer, and everything here is decidable in a unit test.
library;

import 'channel.dart';

/// The key this build asks about in the `/v1/version` table.
///
/// Android splits by distribution channel (Play vs the direct APK have
/// different update actions, and genuinely drift apart in version). Desktop
/// splits by OS only for now: the per-package split (portable vs setup) is a
/// v1.4 concern — both Windows artifacts are built by the same workflow run
/// and always carry the same version, and the v1.3 action for every desktop
/// build is identical: open the download page. `windows-setup` stands in as
/// the representative Windows key.
///
/// [os] is `Platform.operatingSystem`, injected so tests can exercise every
/// branch on one machine.
String updateChannelKey({required String os, AvaChannel channel = avaChannel}) {
  switch (os) {
    case 'android':
      return channel == AvaChannel.play ? 'android-play' : 'android-cn';
    case 'windows':
      return 'windows-setup';
    case 'linux':
      return 'linux-appimage';
    case 'macos':
      return 'macos-dmg';
    default:
      // Unknown platform: ask about a key the table will never contain, and
      // the "absent key = no update information" rule quietly does the rest.
      return 'unknown';
  }
}

/// Compares two dotted numeric versions. Returns >0 when [a] is newer.
///
/// Numeric per segment, NOT lexicographic: '1.10.0' must beat '1.9.0', which
/// string comparison gets wrong. Non-numeric segment content is ignored
/// ('1.2.0-beta' compares as 1.2.0) — the endpoint publishes plain semver, so
/// anything fancier arriving means a broken table, and a broken table must
/// never produce an update prompt.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0)
      .toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final da = i < pa.length ? pa[i] : 0;
    final db = i < pb.length ? pb[i] : 0;
    if (da != db) return da - db;
  }
  return 0;
}

/// What the launch-time check concluded. [available] is true when the remote
/// version is strictly newer. Dismissal is session-only (the banner's Skip
/// clears the in-memory state); with auto-check on, every launch re-announces
/// — 2026-08-15 owner decision, replacing the persisted per-version skip.
class UpdateDecision {
  const UpdateDecision({required this.available, this.latest});

  final bool available;
  final String? latest;

  static const none = UpdateDecision(available: false);
}

/// Pure decision from the fetched table.
///
/// [channels] is the decoded `channels` map from `/v1/version`; anything
/// malformed in it — missing key, missing version, non-string — lands on
/// [UpdateDecision.none]. A broken or hostile response must degrade to
/// silence, never to a prompt.
UpdateDecision decideUpdate({
  required Map<String, dynamic>? channels,
  required String channelKey,
  required String currentVersion,
}) {
  if (channels == null) return UpdateDecision.none;
  final entry = channels[channelKey];
  if (entry is! Map) return UpdateDecision.none;
  final latest = entry['version'];
  if (latest is! String || latest.isEmpty) return UpdateDecision.none;
  if (compareVersions(latest, currentVersion) <= 0) return UpdateDecision.none;
  return UpdateDecision(available: true, latest: latest);
}
