import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';

class PortableModeCard extends ConsumerStatefulWidget {
  const PortableModeCard({super.key});
  @override
  ConsumerState<PortableModeCard> createState() => _PortableModeCardState();
}

class _PortableModeCardState extends ConsumerState<PortableModeCard> {
  bool _busy = false;
  String? _message;

  Future<String?> _password({required bool create}) async {
    final l = AppLocalizations.of(context);
    final first = TextEditingController();
    final second = TextEditingController();
    final form = GlobalKey<FormState>();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(create ? l.portableSetPassword : l.portableUnlock),
          content: SingleChildScrollView(
            padding: ctx.rSafeInsets(),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(create ? l.portablePasswordHelp : l.portableUnlockHelp),
                  TextFormField(
                    controller: first,
                    autofocus: true,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l.loginPassword),
                    validator: (v) => (v ?? '').length < (create ? 12 : 1)
                        ? l.portablePasswordHelp
                        : null,
                    onFieldSubmitted: create
                        ? null
                        : (_) {
                            if (form.currentState!.validate()) {
                              Navigator.pop(ctx, first.text);
                            }
                          },
                  ),
                  if (create)
                    TextFormField(
                      controller: second,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l.portableConfirmPassword,
                      ),
                      validator: (v) =>
                          v != first.text ? l.portablePasswordMismatch : null,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, first.text);
                }
              },
              child: Text(l.commonOk),
            ),
          ],
        ),
      );
    } finally {
      first.dispose();
      second.dispose();
    }
  }

  Future<bool> _unlockIfNeeded() async {
    final library = ref.read(appControllerProvider).value!.portable!;
    if (!library.locked) return true;
    final password = await _password(create: false);
    if (password == null || !mounted) return false;
    if (!await library.unlock(password)) {
      if (mounted) {
        setState(
          () => _message = AppLocalizations.of(context).portableWrongPassword,
        );
      }
      return false;
    }
    await ref.read(appControllerProvider.notifier).reload();
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = '${AppLocalizations.of(context).portableFailed}\n$e',
        );
      }
    } finally {
      if (mounted) {
        await ref.read(appControllerProvider.notifier).reload();
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggle(bool enabled) => _run(() async {
    final l = AppLocalizations.of(context);
    final library = ref.read(appControllerProvider).value!.portable!;
    final copy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(enabled ? l.portableEnable : l.portableDisable),
        content: Text(
          '${enabled ? l.portableCopyToUsb : l.portableCopyToLocal}\n\n${l.portableCopyHelp}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.portableNoCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.portableCopy),
          ),
        ],
      ),
    );
    if (copy == null || !mounted) return;
    if ((enabled || copy) && !await _unlockIfNeeded()) return;
    if (!mounted) return;
    if (enabled && !library.configured) {
      final password = await _password(create: true);
      if (password == null || !mounted) return;
      await library.configure(password);
    }
    final skipped = await ref
        .read(appControllerProvider.notifier)
        .setPortableMode(enabled, migrate: copy);
    if (mounted) {
      setState(
        () => _message = '${l.portableDone}\n${l.portableSkipped}: $skipped',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(appControllerProvider).value?.portable;
    if (library == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.portableMode),
              value: library.enabled,
              onChanged: _busy || library.error != null || library.foreignVault
                  ? null
                  : _toggle,
            ),
            Text(library.enabled ? l.portableOnHelp : l.portableOffHelp),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: library.storage.maFilesDir(),
              builder: (_, snap) => SelectableText(
                snap.data ?? 'maFiles',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (library.error != null || library.foreignVault)
              Text(
                l.portableUnreadable,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (library.locked &&
                !library.foreignVault &&
                library.error == null)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _unlockIfNeeded();
                      }),
                icon: const Icon(Icons.lock_open),
                label: Text(l.portableUnlock),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Expose the discovered library even on an otherwise empty home screen.
class PortableLibraryBanner extends ConsumerWidget {
  const PortableLibraryBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(appControllerProvider).value?.portable;
    if (library == null ||
        (!library.locked &&
            !library.enabled &&
            library.error == null &&
            (!library.hasData || library.configured))) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: TextButton.icon(
        icon: Icon(library.locked ? Icons.lock_outline : Icons.usb),
        label: Text(library.locked ? l.portableUnlock : l.portableMode),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(l.portableMode)),
              body: ListView(
                padding: context.rSafeInsets(all: 16),
                children: const [PortableModeCard()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
