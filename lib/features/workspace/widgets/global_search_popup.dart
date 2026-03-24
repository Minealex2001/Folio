import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';

class GlobalSearchPopup extends StatefulWidget {
  const GlobalSearchPopup({super.key, required this.session});

  final VaultSession session;

  @override
  State<GlobalSearchPopup> createState() => _GlobalSearchPopupState();
}

class _GlobalSearchPopupState extends State<GlobalSearchPopup> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<VaultSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _results = widget.session.searchGlobal(_query.text);
    });
  }

  void _pick(VaultSearchResult result) {
    widget.session.selectPage(result.pageId);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _query,
                focusNode: _focus,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.searchAllVaultHint,
                ),
                onChanged: (_) => _refresh(),
                onSubmitted: (_) {
                  if (_results.isNotEmpty) _pick(_results.first);
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _query.text.trim().isEmpty
                    ? Center(
                        child: Text(
                          l10n.typeToSearch,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noSearchResults,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(
                              r.pageTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              r.snippet,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pick(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniUnlockDialog extends StatefulWidget {
  const MiniUnlockDialog({super.key, required this.session});

  final VaultSession session;

  @override
  State<MiniUnlockDialog> createState() => _MiniUnlockDialogState();
}

class _MiniUnlockDialogState extends State<MiniUnlockDialog> {
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.unlockWithPassword(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).miniUnlockFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.unlockVaultTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TextField(
          controller: _password,
          obscureText: _obscure,
          enabled: !_busy,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.masterPassword,
            suffixIcon: IconButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
          onSubmitted: (_) => _unlock(),
        ),
      ),
      actions: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: Text(l10n.unlock),
        ),
      ],
    );
  }
}
