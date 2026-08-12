/// The three-way merge that decides what a sync round does.
///
/// Per account there are three observations:
///  - LOCAL:  the account's current payload hash on this device (or absent);
///  - BASE:   what this device last synced (rev + hash, or absent);
///  - REMOTE: the sidecar's live entry or tombstone (or absent).
///
/// "Changed" is judged against BASE — locally by content hash (so a session
/// refresh, which never enters the payload, is a no-op), remotely by Lamport
/// revision. Wall clocks decide nothing: two devices' clocks aren't
/// comparable, revisions are.
///
/// Both-changed is a conflict ONLY when the content actually differs — two
/// devices independently arriving at the same payload (both refreshed the
/// same new avatar) converge silently.
///
/// Pure: no IO, no Flutter. Everything is testable as data in, plan out.
library;

import 'sync_payload.dart';

/// What this device last synced for one account.
class SyncBaseEntry {
  final int rev;
  final String hash;
  const SyncBaseEntry({required this.rev, required this.hash});

  factory SyncBaseEntry.fromJson(Map<String, dynamic> json) => SyncBaseEntry(
        rev: (json['rev'] as num?)?.toInt() ?? 0,
        hash: (json['hash'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'rev': rev, 'hash': hash};
}

enum SyncConflictKind {
  /// Both sides changed the account, to different content.
  editEdit,

  /// This device changed it; another device deleted it.
  editDelete,

  /// This device deleted it; another device changed it.
  deleteEdit,
}

class SyncConflict {
  final int steamId;
  final SyncConflictKind kind;

  /// The remote live entry (null for [SyncConflictKind.editDelete]).
  final SyncRemoteAccount? remote;

  /// The remote tombstone (only for [SyncConflictKind.editDelete]).
  final SyncTombstone? tombstone;

  const SyncConflict({
    required this.steamId,
    required this.kind,
    this.remote,
    this.tombstone,
  });
}

/// One push the executor must perform: encrypt the local payload and upload
/// it under [newRev].
class SyncPush {
  final int steamId;
  final int newRev;
  const SyncPush({required this.steamId, required this.newRev});
}

/// One pull: download + decrypt [remote] and apply it locally.
class SyncPull {
  final int steamId;
  final SyncRemoteAccount remote;
  const SyncPull({required this.steamId, required this.remote});
}

/// Apply a remote deletion locally (the local copy goes to the trash first).
class SyncLocalDelete {
  final int steamId;
  final SyncTombstone tombstone;
  const SyncLocalDelete({required this.steamId, required this.tombstone});
}

/// Propagate a local deletion: write a tombstone at [newRev].
class SyncTombstonePush {
  final int steamId;
  final int newRev;
  const SyncTombstonePush({required this.steamId, required this.newRev});
}

/// Adopt the remote's bookkeeping without moving any data (content already
/// identical, a tombstone for an account this device never had, or a base
/// entry that no longer corresponds to anything anywhere).
class SyncBaseAdopt {
  final int steamId;
  final int rev;
  final String hash;

  /// True adopts a tombstone (base entry is removed, tombstone recorded).
  final bool tombstone;

  /// True drops the base entry entirely (account gone on every side).
  final bool drop;

  const SyncBaseAdopt({
    required this.steamId,
    required this.rev,
    this.hash = '',
    this.tombstone = false,
    this.drop = false,
  });
}

class SyncPlan {
  final List<SyncPush> pushes;
  final List<SyncPull> pulls;
  final List<SyncLocalDelete> localDeletes;
  final List<SyncTombstonePush> tombstonePushes;
  final List<SyncBaseAdopt> baseAdopts;
  final List<SyncConflict> conflicts;

  const SyncPlan({
    this.pushes = const [],
    this.pulls = const [],
    this.localDeletes = const [],
    this.tombstonePushes = const [],
    this.baseAdopts = const [],
    this.conflicts = const [],
  });

  bool get isEmpty =>
      pushes.isEmpty &&
      pulls.isEmpty &&
      localDeletes.isEmpty &&
      tombstonePushes.isEmpty &&
      baseAdopts.isEmpty &&
      conflicts.isEmpty;

  /// Anything that mutates the remote.
  bool get pushesAnything => pushes.isNotEmpty || tombstonePushes.isNotEmpty;
}

/// Computes the plan for one sync round.
///
/// [localHashes]: current payload hash per local account.
/// [base]: what this device last synced.
/// [tombstonesSeen]: tombstone revisions this device has already applied or
/// noted — the signal that separates "deliberately re-imported after the
/// delete" (resurrect) from "first sync of a device that never heard about
/// the delete" (a human must decide).
/// [remote]: the sidecar just fetched (empty sidecar for a fresh remote).
/// [forcePushAll]: re-push every local account even when unchanged — used
/// after the include-passwords toggle or a passphrase change, where the
/// remote *ciphertext* must change even though payload hashes may not.
SyncPlan planSync({
  required Map<int, String> localHashes,
  required Map<int, SyncBaseEntry> base,
  required SyncSidecar remote,
  Map<int, int> tombstonesSeen = const {},
  bool forcePushAll = false,
}) {
  final pushes = <SyncPush>[];
  final pulls = <SyncPull>[];
  final localDeletes = <SyncLocalDelete>[];
  final tombstonePushes = <SyncTombstonePush>[];
  final baseAdopts = <SyncBaseAdopt>[];
  final conflicts = <SyncConflict>[];

  final ids = <int>{
    ...localHashes.keys,
    ...base.keys,
    ...remote.accounts.keys,
    ...remote.tombstones.keys,
  };

  for (final id in ids) {
    final localHash = localHashes[id];
    final b = base[id];
    final r = remote.accounts[id];
    final t = remote.tombstones[id];

    // Invariant: an id is live or tombstoned, not both. A malformed sidecar
    // (interrupted third-party edit) resolves by revision, higher wins.
    final effectiveR = (r != null && t != null && t.rev > r.rev) ? null : r;
    final effectiveT = (r != null && t != null && t.rev <= r.rev) ? null : t;

    final localExists = localHash != null;
    final localChanged =
        localExists && (b == null || localHash != b.hash || forcePushAll);
    final remoteChanged = effectiveR != null && (b == null || effectiveR.rev != b.rev);
    // A tombstone is news when it out-revs what this device last synced.
    final remoteDeleted =
        effectiveT != null && (b == null || effectiveT.rev > b.rev);

    if (localExists) {
      if (effectiveR != null) {
        if (localChanged && remoteChanged) {
          if (localHash == effectiveR.hash && !forcePushAll) {
            // Same content reached independently — converge without a push.
            baseAdopts.add(SyncBaseAdopt(
                steamId: id, rev: effectiveR.rev, hash: effectiveR.hash));
          } else if (localHash == effectiveR.hash && forcePushAll) {
            pushes.add(SyncPush(steamId: id, newRev: effectiveR.rev + 1));
          } else {
            conflicts.add(SyncConflict(
                steamId: id,
                kind: SyncConflictKind.editEdit,
                remote: effectiveR));
          }
        } else if (localChanged) {
          pushes.add(SyncPush(steamId: id, newRev: effectiveR.rev + 1));
        } else if (remoteChanged) {
          pulls.add(SyncPull(steamId: id, remote: effectiveR));
        }
        // else: quiet on both sides — nothing.
      } else if (effectiveT != null &&
          (tombstonesSeen[id] ?? -1) >= effectiveT.rev) {
        // Tombstone this device already applied or noted, yet the account
        // exists locally again: a deliberate local re-import. Resurrect —
        // the re-import is the newer intent.
        pushes.add(SyncPush(steamId: id, newRev: effectiveT.rev + 1));
      } else if (remoteDeleted) {
        if (localChanged || b == null) {
          // Either edited on top of the last sync, or never synced here at
          // all (a first-connect device may hold a stale pre-delete copy, or
          // a deliberately re-imported one — only the user knows which).
          conflicts.add(SyncConflict(
              steamId: id,
              kind: SyncConflictKind.editDelete,
              tombstone: effectiveT));
        } else {
          localDeletes.add(SyncLocalDelete(steamId: id, tombstone: effectiveT));
        }
      } else {
        // Not on the remote at all: new local account (or the remote lost
        // it). Push at a rev past anything this device ever saw for the id.
        pushes.add(SyncPush(steamId: id, newRev: (b?.rev ?? 0) + 1));
      }
    } else if (b != null) {
      // This device deleted the account after last syncing it.
      if (effectiveR != null) {
        if (effectiveR.rev == b.rev) {
          tombstonePushes.add(
              SyncTombstonePush(steamId: id, newRev: effectiveR.rev + 1));
        } else {
          // Someone changed it after we deleted — a human must decide.
          conflicts.add(SyncConflict(
              steamId: id,
              kind: SyncConflictKind.deleteEdit,
              remote: effectiveR));
        }
      } else if (effectiveT != null) {
        // Both deleted; adopt the remote tombstone.
        baseAdopts.add(
            SyncBaseAdopt(steamId: id, rev: effectiveT.rev, tombstone: true));
      } else {
        // Gone everywhere; drop the stale base entry.
        baseAdopts.add(SyncBaseAdopt(steamId: id, rev: 0, drop: true));
      }
    } else {
      // No local copy, never synced here.
      if (effectiveR != null) {
        pulls.add(SyncPull(steamId: id, remote: effectiveR));
      } else if (effectiveT != null) {
        // Tombstone for an account this device never had — note it so a
        // later import of the same account resurrects at the right rev.
        baseAdopts.add(
            SyncBaseAdopt(steamId: id, rev: effectiveT.rev, tombstone: true));
      }
    }
  }

  return SyncPlan(
    pushes: pushes,
    pulls: pulls,
    localDeletes: localDeletes,
    tombstonePushes: tombstonePushes,
    baseAdopts: baseAdopts,
    conflicts: conflicts,
  );
}
