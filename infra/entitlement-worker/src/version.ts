/// GET /v1/version — the update-check endpoint (docs/plans/2026-08-14-update-checker.md).
///
/// Deliberately dumb: a constant table, no storage, no per-request state. This
/// endpoint stores nothing and logs nothing — there is no logging call in this
/// worker and no analytics binding in wrangler.jsonc; keeping it that way is a
/// privacy commitment (PRIVACY.md §3), not an implementation accident.
///
/// One entry per (platform, channel) because the channels genuinely drift:
/// on 2026-08-14 Play and the cn APK were on 1.0.1 while the newest desktop
/// release carried 1.1.0. A single "latest" would tell some client a lie.
///
/// RELEASE CHECKLIST: bump the versions below and `wrangler deploy`, then
/// curl the endpoint and check what it answers. Nothing fails when this table
/// goes stale — clients just stop learning about updates — which is exactly
/// how site.ts handed out v0.80.1 downloads for nine releases.

interface VersionEntry {
  /// Newest version actually downloadable for this key, as plain semver.
  version: string;
}

/// Verified against the live channels on 2026-08-14:
/// Play production 1.0.1 (versionCode 54), R2 cn APK 1.0.1, GitHub release
/// v1.1 whose assets are 1.1.0. 1.2.0 exists in dist/ but is unpublished —
/// advertising it here before it is downloadable would send users to a
/// download that does not exist.
const VERSIONS: Record<string, VersionEntry> = {
  // 1.2.0 released 2026-08-15: Play production versionCode 58, cn APK on R2,
  // GitHub release v1.2 with four desktop artifacts — including the first
  // macOS DMG, which is why macos-dmg exists now and not before.
  'android-play': { version: '1.2.0' },
  'android-cn': { version: '1.2.0' },
  'windows-portable': { version: '1.2.0' },
  'windows-setup': { version: '1.2.0' },
  'linux-appimage': { version: '1.2.0' },
  'macos-dmg': { version: '1.2.0' },
};

/// The whole response is static, so let the edge serve it: an hour of caching
/// makes most launch-time checks terminate at the CDN without ever running
/// this worker, and a one-hour delay on update visibility is nothing against
/// a store review cycle.
export function handleVersion(): Response {
  return new Response(JSON.stringify({ channels: VERSIONS }), {
    status: 200,
    headers: {
      'content-type': 'application/json',
      'cache-control': 'public, max-age=3600',
      'strict-transport-security': 'max-age=63072000; includeSubDomains',
    },
  });
}
