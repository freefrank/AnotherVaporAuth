import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/core/sync/sync_planner.dart';
import 'package:flutter_test/flutter_test.dart';

// The planner is the sync feature's brain: every (local, base, remote)
// combination maps to exactly one action. These tests walk the decision
// table case by case — anything not covered here is a merge behaviour
// nobody decided.

SyncRemoteAccount remoteAcc(int rev, String hash) => SyncRemoteAccount(
      rev: rev,
      hash: hash,
      filename: 'x.r$rev.aaaa.maFile',
      salt: 's',
      iv: 'i',
    );

void main() {
  group('planSync — clean states', () {
    test('everything in agreement is a no-op', () {
      final plan = planSync(
        localHashes: {1: 'h1'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(3, 'h1')}),
      );
      expect(plan.isEmpty, isTrue);
    });

    test('new local account pushes at rev 1', () {
      final plan = planSync(
        localHashes: {1: 'h1'},
        base: const {},
        remote: const SyncSidecar(),
      );
      expect(plan.pushes.single.steamId, 1);
      expect(plan.pushes.single.newRev, 1);
      expect(plan.conflicts, isEmpty);
    });

    test('new remote account pulls', () {
      final plan = planSync(
        localHashes: const {},
        base: const {},
        remote: SyncSidecar(accounts: {1: remoteAcc(2, 'h1')}),
      );
      expect(plan.pulls.single.steamId, 1);
      expect(plan.pulls.single.remote.rev, 2);
    });

    test('local change pushes past the remote rev', () {
      final plan = planSync(
        localHashes: {1: 'h2'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(3, 'h1')}),
      );
      expect(plan.pushes.single.newRev, 4);
    });

    test('remote change pulls', () {
      final plan = planSync(
        localHashes: {1: 'h1'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(5, 'h2')}),
      );
      expect(plan.pulls.single.remote.rev, 5);
      expect(plan.pushes, isEmpty);
    });
  });

  group('planSync — deletions', () {
    test('local delete propagates as a tombstone', () {
      final plan = planSync(
        localHashes: const {},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(3, 'h1')}),
      );
      expect(plan.tombstonePushes.single.steamId, 1);
      expect(plan.tombstonePushes.single.newRev, 4);
    });

    test('remote tombstone deletes locally when local is unchanged', () {
      final plan = planSync(
        localHashes: {1: 'h1'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(
            tombstones: {1: const SyncTombstone(rev: 4)}),
      );
      expect(plan.localDeletes.single.steamId, 1);
      expect(plan.conflicts, isEmpty);
    });

    test('a tombstone this device already applied stays quiet', () {
      // Base has no entry (removed when the tombstone was applied); the
      // account no longer exists locally.
      final plan = planSync(
        localHashes: const {},
        base: const {},
        remote:
            SyncSidecar(tombstones: {1: const SyncTombstone(rev: 4)}),
      );
      expect(plan.localDeletes, isEmpty);
      expect(plan.baseAdopts.single.tombstone, isTrue);
      expect(plan.baseAdopts.single.rev, 4);
    });

    test('re-import after a SEEN tombstone resurrects past its rev', () {
      // This device applied the tombstone earlier (it is in tombstonesSeen)
      // and the account exists again — a deliberate re-import.
      final plan = planSync(
        localHashes: {1: 'h9'},
        base: const {},
        tombstonesSeen: const {1: 7},
        remote:
            SyncSidecar(tombstones: {1: const SyncTombstone(rev: 7)}),
      );
      expect(plan.pushes.single.newRev, 8);
      expect(plan.localDeletes, isEmpty);
      expect(plan.conflicts, isEmpty);
    });

    test('an UNSEEN tombstone against a never-synced local copy is a '
        'conflict, not a silent delete or resurrect', () {
      // First connect of a device that still holds the account while the
      // remote says deleted: only the user knows whether their copy is a
      // stale leftover or a deliberate re-import.
      final plan = planSync(
        localHashes: {1: 'h9'},
        base: const {},
        remote:
            SyncSidecar(tombstones: {1: const SyncTombstone(rev: 7)}),
      );
      expect(plan.conflicts.single.kind, SyncConflictKind.editDelete);
      expect(plan.pushes, isEmpty);
      expect(plan.localDeletes, isEmpty);
    });

    test('both sides deleted converges without a push', () {
      final plan = planSync(
        localHashes: const {},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote:
            SyncSidecar(tombstones: {1: const SyncTombstone(rev: 4)}),
      );
      expect(plan.tombstonePushes, isEmpty);
      expect(plan.baseAdopts.single.tombstone, isTrue);
    });

    test('account gone everywhere drops the stale base entry', () {
      final plan = planSync(
        localHashes: const {},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: const SyncSidecar(),
      );
      expect(plan.baseAdopts.single.drop, isTrue);
    });
  });

  group('planSync — conflicts', () {
    test('edit/edit with different content conflicts', () {
      final plan = planSync(
        localHashes: {1: 'hLocal'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(5, 'hRemote')}),
      );
      expect(plan.conflicts.single.kind, SyncConflictKind.editEdit);
      expect(plan.pushes, isEmpty);
      expect(plan.pulls, isEmpty);
    });

    test('edit/edit with identical content converges silently', () {
      final plan = planSync(
        localHashes: {1: 'hSame'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(5, 'hSame')}),
      );
      expect(plan.conflicts, isEmpty);
      expect(plan.baseAdopts.single.rev, 5);
    });

    test('independent creation with identical content adopts', () {
      final plan = planSync(
        localHashes: {1: 'hSame'},
        base: const {},
        remote: SyncSidecar(accounts: {1: remoteAcc(2, 'hSame')}),
      );
      expect(plan.conflicts, isEmpty);
      expect(plan.baseAdopts.single.rev, 2);
    });

    test('independent creation with different content conflicts', () {
      final plan = planSync(
        localHashes: {1: 'hA'},
        base: const {},
        remote: SyncSidecar(accounts: {1: remoteAcc(2, 'hB')}),
      );
      expect(plan.conflicts.single.kind, SyncConflictKind.editEdit);
    });

    test('local edit vs remote delete conflicts', () {
      final plan = planSync(
        localHashes: {1: 'hChanged'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote:
            SyncSidecar(tombstones: {1: const SyncTombstone(rev: 4)}),
      );
      expect(plan.conflicts.single.kind, SyncConflictKind.editDelete);
      expect(plan.localDeletes, isEmpty);
    });

    test('local delete vs remote edit conflicts', () {
      final plan = planSync(
        localHashes: const {},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(5, 'h2')}),
      );
      expect(plan.conflicts.single.kind, SyncConflictKind.deleteEdit);
      expect(plan.tombstonePushes, isEmpty);
    });
  });

  group('planSync — sidecar invariant repair', () {
    test('live entry and tombstone for the same id: higher rev wins', () {
      // Tombstone newer → account is dead.
      final dead = planSync(
        localHashes: {1: 'h1'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(
          accounts: {1: remoteAcc(3, 'h1')},
          tombstones: {1: const SyncTombstone(rev: 4)},
        ),
      );
      expect(dead.localDeletes, hasLength(1));

      // Live entry newer → tombstone is stale noise.
      final alive = planSync(
        localHashes: {1: 'h1'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(
          accounts: {1: remoteAcc(5, 'h2')},
          tombstones: {1: const SyncTombstone(rev: 4)},
        ),
      );
      expect(alive.pulls, hasLength(1));
      expect(alive.localDeletes, isEmpty);
    });
  });

  group('planSync — forcePushAll', () {
    test('re-pushes even unchanged accounts', () {
      final plan = planSync(
        localHashes: {1: 'h1'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(3, 'h1')}),
        forcePushAll: true,
      );
      expect(plan.pushes.single.newRev, 4);
    });

    test('does not turn a real divergence into a push', () {
      // Both sides changed to different content: still a conflict, force or
      // not — forcePushAll must never silently overwrite another device.
      final plan = planSync(
        localHashes: {1: 'hLocal'},
        base: {1: const SyncBaseEntry(rev: 3, hash: 'h1')},
        remote: SyncSidecar(accounts: {1: remoteAcc(5, 'hRemote')}),
        forcePushAll: true,
      );
      expect(plan.conflicts, hasLength(1));
      expect(plan.pushes, isEmpty);
    });
  });
}
