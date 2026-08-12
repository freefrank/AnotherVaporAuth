/// Riverpod wiring for the sync engine: constructs it, adapts AppController
/// to the engine's accounts port, and republishes its status for the UI.
library;

import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/steam_guard_account.dart';
import '../services/sync/sync_config_store.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/sync_trash.dart';
import '../services/sync/webdav_transport.dart';
import 'providers.dart';

/// The engine. Kept alive by _Root watching [syncStatusProvider]; account
/// list changes flow in through the listener below, so every store mutation
/// (import, delete, password change) schedules a debounced round.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final storage = ref.read(storageProvider);
  final engine = SyncEngine(
    configStore: SyncConfigStore(storage),
    accounts: AppAccountsPort(ref),
    trash: SyncTrash(storage),
    transportFactory: buildWebDavTransport,
    deviceId: () => ref.read(deviceIdProvider.future),
  );
  ref.onDispose(engine.dispose);
  engine.start();
  ref.listen(appControllerProvider, (prev, next) {
    final data = next.value;
    if (data != null && !data.locked) engine.notifyAccountsChanged();
  });
  return engine;
});

/// Builds the WebDAV transport for [config]. Shared by the engine and the
/// setup wizard so both apply the identical pin + HTTP policy.
WebDavTransport buildWebDavTransport(SyncConfig config, String password) {
  final url = Uri.parse(config.url);
  return WebDavTransport(
    url: url,
    username: config.username,
    password: password,
    pinnedCertSha256: config.pinnedCerts[url.host.toLowerCase()],
    httpOverrides: config.httpOverrides,
  );
}

/// The engine's status as UI-watchable state.
final syncStatusProvider =
    NotifierProvider<SyncStatusController, SyncEngineStatus>(
        SyncStatusController.new);

class SyncStatusController extends Notifier<SyncEngineStatus> {
  @override
  SyncEngineStatus build() {
    final engine = ref.watch(syncEngineProvider);
    final sub = engine.statusStream.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return engine.status;
  }
}

/// Adapts AppController to the engine's port. Pulls reuse the maFile import
/// path (same normalization + enrichment/session merge as a manual import);
/// removals go through the same controller path the UI uses.
class AppAccountsPort implements SyncAccountsPort {
  final Ref ref;
  AppAccountsPort(this.ref);

  @override
  List<SteamGuardAccount>? snapshot() {
    final data = ref.read(appControllerProvider).value;
    if (data == null || data.locked) return null;
    return data.accounts;
  }

  @override
  Future<void> applyRemote(Map<String, dynamic> payload) async {
    await ref
        .read(appControllerProvider.notifier)
        .importMaFile(jsonEncode(payload), sourceName: 'sync');
  }

  @override
  Future<void> removeAccount(int steamId) async {
    final data = ref.read(appControllerProvider).value;
    if (data == null) return;
    final acc = data.accounts.firstWhereOrNull((a) => a.steamId == steamId);
    if (acc != null) {
      await ref.read(appControllerProvider.notifier).removeAccount(acc);
    } else {
      await ref
          .read(appControllerProvider.notifier)
          .removeAccountBySteamId(steamId);
    }
  }
}
