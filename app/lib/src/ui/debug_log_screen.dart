import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../services/debug_log.dart';

/// Shows the in-app network/debug log (the `dlog` ring buffer) so the networked
/// Steam flows can be inspected and copied on a real device.
class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<SdaTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug log'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: DebugLog.instance.dump()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied')),
              );
            },
          ),
          IconButton(
            tooltip: 'Clear',
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
              child: Text('No log yet.', style: TextStyle(color: t.muted)),
            );
          }
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final line = lines[lines.length - 1 - i];
              final isErr = line.contains('✗') || line.contains('error');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: SelectableText(
                  line,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
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
