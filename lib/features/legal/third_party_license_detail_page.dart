import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../legal/third_party_license.dart';
import 'third_party_licenses_page.dart';

class ThirdPartyLicenseDetailPage extends StatelessWidget {
  const ThirdPartyLicenseDetailPage({super.key, required this.entry});

  final ThirdPartyLicenseEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                entry.name,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _LabeledValue(
                label: l10n.thirdPartyLicensesLicenseLabel,
                value: entry.license,
              ),
              if (entry.hasCopyright) ...[
                const SizedBox(height: 12),
                _LabeledValue(
                  label: l10n.thirdPartyLicensesCopyrightLabel,
                  value: entry.copyright!,
                ),
              ],
              if ((entry.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  entry.description!.trim(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (entry.hasSourceUrl)
                    Semantics(
                      button: true,
                      label: l10n.thirdPartyLicensesOpenRepository,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          final uri = Uri.tryParse(entry.sourceUrl!.trim());
                          if (uri == null) return;
                          launchThirdPartySourceUrl(uri);
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(l10n.thirdPartyLicensesOpenRepository),
                      ),
                    ),
                  if (entry.hasLicenseText)
                    Semantics(
                      button: true,
                      label: l10n.thirdPartyLicensesViewLicense,
                      child:                       OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => _LicenseTextPage(
                                licenseText: entry.licenseText!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.article_outlined),
                        label: Text(l10n.thirdPartyLicensesViewLicense),
                      ),
                    ),
                ],
              ),
              if (entry.hasSourceUrl) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.thirdPartyLicensesSourceLabel,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  entry.sourceUrl!.trim(),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: textTheme.bodyLarge),
      ],
    );
  }
}

class _LicenseTextPage extends StatelessWidget {
  const _LicenseTextPage({required this.licenseText});

  final String licenseText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.thirdPartyLicensesLicenseLabel),
        actions: [
          IconButton(
            tooltip: l10n.thirdPartyLicensesCopyLicense,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: licenseText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.thirdPartyLicensesLicenseCopied)),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                licenseText.trim(),
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
