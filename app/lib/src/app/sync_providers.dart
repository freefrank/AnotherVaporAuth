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
import 'theme.dart';

/// The engine. Kept alive by _Root watching [syncStatusProvider]; account
/// list changes flow in through the listener below, so every store mutation
/// (import, delete, password change) schedules a debounced round.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final storage = ref.read(storageProvider);
  final engine = SyncEngine(
    configStore: SyncConfigStore(storage),
    accounts: AppAccountsPort(ref),
    settings: AppSettingsPort(ref),
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
  // Synced app settings: any change to a curated preference schedules a
  // round, exactly like an account change. Applying a pulled document goes
  // through these same notifiers, which re-fires the listeners — the
  // follow-up round is a hash-equal no-op.
  void onSetting(Object? prev, Object? next) {
    if (prev != null && prev != next) engine.notifyAccountsChanged();
  }

  ref.listen(skinProvider, onSetting);
  ref.listen(brightnessModeProvider, onSetting);
  ref.listen(holdConfirmProvider, onSetting);
  ref.listen(hapticsProvider, onSetting);
  ref.listen(blockScreenshotsProvider, onSetting);
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

/// The curated app-settings document (spec §设置同步): appearance and
/// behavior preferences that mean "the same me on every device". Language
/// and text size are deliberately absent (device-specific), as is anything
/// identity- or consent-shaped (device id, entitlement, privacy version).
///
/// Snapshot reads the settings FILE, not the providers: the provider
/// notifiers publish defaults synchronously and only apply the stored value
/// when their async load lands — hashing that transient state would push
/// this device's defaults over the synced document at every cold start.
class AppSettingsPort implements SyncSettingsPort {
  final Ref ref;
  AppSettingsPort(this.ref);

  @override
  Future<Map<String, dynamic>?> snapshot() async {
    final data = ref.read(appControllerProvider).value;
    if (data == null || data.locked) return null;
    final store = ref.read(settingsStoreProvider);
    return {
      'skin': (await store.loadSkin()) ?? AvaSkin.none.name,
      'brightness_mode':
          (await store.loadBrightnessMode()) ?? AvaBrightnessMode.system.name,
      'hold_confirm': await store.loadHoldConfirm(),
      'haptics': await store.loadHaptics(),
      'block_screenshots': await store.loadBlockScreenshots(),
      'auto_confirm_market':
          data.store.manifest.autoConfirmMarketTransactions,
    };
  }

  @override
  Future<void> apply(Map<String, dynamic> doc) async {
    // Through the notifiers, so the UI updates live and each value
    // persists via its own write-through path.
    final skin = doc['skin'];
    if (skin is String) {
      final v = AvaSkin.values.firstWhereOrNull((s) => s.name == skin);
      if (v != null) await ref.read(skinProvider.notifier).setSkin(v);
    }
    final mode = doc['brightness_mode'];
    if (mode is String) {
      final v = AvaBrightnessMode.values
          .firstWhereOrNull((m) => m.name == mode);
      if (v != null) {
        await ref.read(brightnessModeProvider.notifier).setMode(v);
      }
    }
    if (doc['hold_confirm'] is bool) {
      await ref
          .read(holdConfirmProvider.notifier)
          .set(doc['hold_confirm'] as bool);
    }
    if (doc['haptics'] is bool) {
      await ref.read(hapticsProvider.notifier).set(doc['haptics'] as bool);
    }
    if (doc['block_screenshots'] is bool) {
      await ref
          .read(blockScreenshotsProvider.notifier)
          .set(doc['block_screenshots'] as bool);
    }
    final autoConfirm = doc['auto_confirm_market'];
    final data = ref.read(appControllerProvider).value;
    if (autoConfirm is bool &&
        data != null &&
        data.store.manifest.autoConfirmMarketTransactions != autoConfirm) {
      data.store.manifest.autoConfirmMarketTransactions = autoConfirm;
      await ref.read(appControllerProvider.notifier).saveSettings();
    }
  }
}
