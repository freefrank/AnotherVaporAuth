/// Read-only helpers for the setup wizard: probe a prospective remote,
/// verify a passphrase against it, and preview what the first sync would do
/// — all before anything is saved or written.
library;

import 'dart:convert';

import '../../core/models/steam_guard_account.dart';
import '../../core/sync/sync_payload.dart';
import '../../core/sync/sync_planner.dart';
import '../../core/sync/sync_transport.dart';
import 'sync_engine.dart';

/// What a prospective remote looks like.
class RemoteInspection {
  /// A sidecar exists — this is an existing sync library.
  final bool exists;
  final int accountCount;
  final bool includePasswords;
  final SyncSidecar? sidecar;

  const RemoteInspection({
    required this.exists,
    this.accountCount = 0,
    this.includePasswords = true,
    this.sidecar,
  });
}

Future<RemoteInspection> inspectRemote(SyncTransport transport) async {
  final file = await transport.getFile(kSyncSidecarFilename);
  if (file == null) return const RemoteInspection(exists: false);
  final sidecar = SyncSidecar.parse(utf8.decode(file.bytes));
  return RemoteInspection(
    exists: true,
    accountCount: sidecar.accounts.length,
    includePasswords: sidecar.includePasswords,
    sidecar: sidecar,
  );
}

/// Verifies [passphrase] against an existing remote: the passkey_check token
/// when present, else a test-decrypt of one account file (older remotes).
/// True on an empty remote — there is nothing to contradict it.
Future<bool> verifyRemotePassphrase(
    SyncTransport transport, SyncSidecar sidecar, String passphrase) async {
  final byToken = verifyPasskeyCheck(passphrase, sidecar.passkeyCheck);
  if (byToken != null) return byToken;
  if (sidecar.accounts.isEmpty) return true;
  final probe = sidecar.accounts.values.first;
  final file = await transport.getFile(probe.filename);
  if (file == null) return true; // nothing to test against
  return decryptSyncPayload(
          passphrase, probe.salt, probe.iv, utf8.decode(file.bytes)) !=
      null;
}

/// What the first sync would do, computed locally against the fetched
/// sidecar. Names for pulled accounts are not known yet (the sidecar is
/// deliberately name-free), so the preview reports counts plus steamids.
SyncPreview previewFirstSync({
  required SyncSidecar? sidecar,
  required List<SteamGuardAccount> local,
  required bool includePasswords,
}) {
  final localHashes = {
    for (final a in local)
      a.steamId:
          payloadHash(syncPayloadJson(a, includePassword: includePasswords))
  };
  final plan = planSync(
    localHashes: localHashes,
    base: const {},
    remote: sidecar ?? const SyncSidecar(),
  );
  return SyncPreview(
    pulls: plan.pulls.length,
    pushes: plan.pushes.length,
    conflicts: plan.conflicts.length,
    pullNames: [for (final p in plan.pulls) '${p.steamId}'],
  );
}
