import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../core/models/confirmation.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/confirmations_client.dart';

class ConfirmationsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const ConfirmationsScreen({super.key, required this.account});

  @override
  ConsumerState<ConfirmationsScreen> createState() =>
      _ConfirmationsScreenState();
}

class _ConfirmationsScreenState extends ConsumerState<ConfirmationsScreen> {
  late final ConfirmationsClient _client;
  List<Confirmation>? _confs;
  final Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ConfirmationsClient(ref.read(apiClientProvider));
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _client.fetch(widget.account);
      if (!mounted) return;
      setState(() {
        _confs = list;
        _selected.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _respondSelected(bool accept) async {
    final confs = _confs ?? const <Confirmation>[];
    final chosen = _selected.isEmpty
        ? confs
        : confs.where((c) => _selected.contains(c.id)).toList();
    if (chosen.isEmpty) return;

    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.confProcessing(chosen.length))),
    );
    final result =
        await _client.respondMultiple(widget.account, chosen, accept);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.confResult(result.ok, result.failed))),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final confs = _confs ?? const <Confirmation>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.confirmationsTitle),
        actions: [
          IconButton(
            tooltip: l.confirmationsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _buildBody(l, confs),
      bottomNavigationBar: confs.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _respondSelected(false),
                        icon: const Icon(Icons.close),
                        label: Text(l.confDeclineSelected),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _respondSelected(true),
                        icon: const Icon(Icons.check),
                        label: Text(l.confAcceptSelected),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(AppLocalizations l, List<Confirmation> confs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${l.commonError}: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (confs.isEmpty) {
      return Center(child: Text(l.confirmationsEmpty));
    }
    return Column(
      children: [
        CheckboxListTile(
          dense: true,
          title: Text(l.confSelectAll),
          value: _selected.length == confs.length,
          onChanged: (v) => setState(() {
            _selected
              ..clear()
              ..addAll(v == true ? confs.map((c) => c.id) : const <String>[]);
          }),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: confs.length,
            itemBuilder: (context, i) {
              final c = confs[i];
              return CheckboxListTile(
                value: _selected.contains(c.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(c.id);
                  } else {
                    _selected.remove(c.id);
                  }
                }),
                title: Text(c.headline.isEmpty ? _typeLabel(l, c) : c.headline),
                subtitle: Text(c.summary.join('\n')),
                isThreeLine: c.summary.length > 1,
                secondary: Chip(label: Text(_typeLabel(l, c))),
              );
            },
          ),
        ),
      ],
    );
  }

  String _typeLabel(AppLocalizations l, Confirmation c) {
    switch (c.type) {
      case ConfirmationType.trade:
        return l.confTypeTrade;
      case ConfirmationType.marketListing:
        return l.confTypeMarket;
      default:
        return l.confTypeOther;
    }
  }
}
