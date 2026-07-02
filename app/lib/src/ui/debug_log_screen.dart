import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../services/debug_log.dart';

/// Shows the in-app network/debug log (the `dlog` ring buffer) so the networked
/// Steam flows can be inspected and copied on a real device.
class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.debugLog),
        actions: [
          IconButton(
            tooltip: l.debugCopyAll,
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: DebugLog.instance.dump()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.debugCopied)),
              );
            },
          ),
          IconButton(
            tooltip: l.commonClear,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => DebugLog.instance.clear(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: DebugLog.instance,
        builder: (context, _) {
          final lines = DebugLog.instance.lines;
          if (lines.isEmpty) {
            return Center(
              child: Text(l.debugEmpty, style: TextStyle(color: t.muted)),
            );
          }
          return ListView.builder(
            reverse: true,
            padding: context.rInsets(all: 12),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final line = lines[lines.length - 1 - i];
              final isErr = line.contains('✗') || line.contains('error');
              return Padding(
                padding: context.rInsets(v: 1),
                child: SelectableText(
                  line,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: context.r(12),
                    color: isErr ? t.bad : t.text,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
