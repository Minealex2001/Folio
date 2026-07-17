part of 'settings_page.dart';

class _FolioCloudGuestPitchTeaser extends StatelessWidget {
  const _FolioCloudGuestPitchTeaser({
    required this.scheme,
    required this.l10n,
    required this.onOpenPitch,
    required this.onShowInkTable,
  });

  final ColorScheme scheme;
  final AppLocalizations l10n;
  final VoidCallback onOpenPitch;
  final VoidCallback onShowInkTable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionSubscription,
          scheme: scheme,
          topPadding: 14,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(FolioRadius.xl),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_outlined, color: scheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.folioCloudPitchGuestTeaserTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.folioCloudPitchGuestTeaserBody,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenPitch,
                    icon: const Icon(Icons.info_outline, size: 20),
                    label: Text(l10n.folioCloudPitchLearnMore),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onShowInkTable,
                    icon: const Icon(Icons.table_chart_outlined, size: 20),
                    label: Text(l10n.settingsViewInkUsageTable),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Folio Cloud plan, ink, and billing UI inside Settings (signed-in only).
class _FolioCloudSubscriptionPanel extends StatelessWidget {
  const _FolioCloudSubscriptionPanel({
    required this.scheme,
    required this.l10n,
    required this.snap,
    required this.busy,
    required this.showMicrosoftStoreBillingNote,
    required this.onSubscribeMonthly,
    required this.onSubscribeFamily,
    required this.onSubscribeStudent,
    required this.onVerifyStudent,
    required this.onRemoveFamilyMember,
    required this.onInviteFamilyMember,
    required this.onOpenPitch,
    required this.onInkSmall,
    required this.onInkMedium,
    required this.onInkLarge,
    required this.onBackupStoragePackSmall,
    required this.onBackupStoragePackMedium,
    required this.onBackupStoragePackLarge,
    required this.onBillingPortal,
    required this.onRefreshBilling,
    required this.onOpenBackups,
    required this.onPublishedPages,
  });

  final ColorScheme scheme;
  final AppLocalizations l10n;
  final FolioCloudSnapshot snap;
  final bool busy;
  final bool showMicrosoftStoreBillingNote;
  final VoidCallback onSubscribeMonthly;
  final VoidCallback onSubscribeFamily;
  final VoidCallback onSubscribeStudent;
  final ValueChanged<String> onVerifyStudent;
  final ValueChanged<String> onRemoveFamilyMember;
  final ValueChanged<String> onInviteFamilyMember;
  final VoidCallback onOpenPitch;
  final VoidCallback onInkSmall;
  final VoidCallback onInkMedium;
  final VoidCallback onInkLarge;
  final VoidCallback onBackupStoragePackSmall;
  final VoidCallback onBackupStoragePackMedium;
  final VoidCallback onBackupStoragePackLarge;
  final VoidCallback onBillingPortal;
  final VoidCallback onRefreshBilling;
  final VoidCallback onOpenBackups;
  final VoidCallback onPublishedPages;

  Future<void> _showInkPricingTable(BuildContext context) {
    const preferredOrder = <String>[
      'rewrite_block',
      'summarize_selection',
      'extract_tasks',
      'summarize_page',
      'generate_insert',
      'generate_page',
      'chat_turn',
      'agent_main',
      'agent_followup',
      'edit_page_panel',
      'default',
    ];

    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final dialogScheme = theme.colorScheme;
        return FolioDialog(
          title: Text(l10n.settingsCloudInkUsageTableTitle),
          content: SizedBox(
            width: 540,
            child: FutureBuilder<FolioCloudAiPricingSnapshot>(
              future: FolioCloudAiPricingService.getPricing(),
              builder: (context, snapshot) {
                final pricing =
                    snapshot.data ?? FolioCloudAiPricingSnapshot.fallback();

                final allKeys = <String>{
                  ...preferredOrder,
                  ...pricing.costByOperation.keys,
                };
                final orderedKeys = <String>[
                  ...preferredOrder.where(allKeys.contains),
                  ...allKeys.where((k) => !preferredOrder.contains(k)).toList()
                    ..sort(),
                ];

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: FolioPricingTableSkeleton(),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.settingsCloudInkUsageTableIntro,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dialogScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (!pricing.fromServer) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.settingsCloudInkTableCachedNotice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: dialogScheme.tertiary,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ...orderedKeys.map((operation) {
                        final drops = pricing.costForOperation(operation);
                        final label = settingsCloudInkOperationLabel(
                          l10n,
                          operation,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: dialogScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: dialogScheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        operation,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  dialogScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$drops',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: dialogScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.settingsCloudInkDrops,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: dialogScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.settingsClose),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget membershipChip({required IconData icon, required String label}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: snap.active
              ? Colors.white.withValues(alpha: 0.15)
              : scheme.surfaceContainerLowest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: snap.active
                ? Colors.white.withValues(alpha: 0.22)
                : scheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: snap.active ? Colors.white : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: snap.active ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    String fmtStorageBytes(int b) {
      if (b < 1024) return '$b B';
      final kb = b / 1024;
      if (kb < 1024) {
        return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
      }
      final mb = kb / 1024;
      if (mb < 1024) {
        return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
      }
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(gb >= 100 ? 1 : 2)} GB';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        if (busy)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
          ),
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionSubscription,
          scheme: scheme,
          topPadding: busy ? 10 : 14,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero: subscription
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: snap.active
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primary,
                            scheme.tertiary,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            scheme.surfaceContainerHigh.withValues(alpha: 0.95),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(FolioRadius.xl),
                  border: Border.all(
                    color: snap.active
                        ? scheme.primary.withValues(alpha: 0.5)
                        : scheme.outlineVariant.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: snap.active
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: snap.active
                                ? Colors.white.withValues(alpha: 0.18)
                                : scheme.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: snap.active
                                ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                                : null,
                          ),
                          child: Icon(
                            snap.active ? Icons.workspace_premium_rounded : Icons.cloud_outlined,
                            color: snap.active ? Colors.white : scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                () {
                                  if (!snap.active) return l10n.folioCloudSubscriptionNoneTitle;
                                  if (snap.isStudent) return l10n.folioCloudPlanActiveStudent;
                                  if (snap.isFamily) {
                                    if (snap.familyOwnerUid != null) return l10n.folioCloudPlanActiveFamilyMember;
                                    return l10n.folioCloudPlanActiveFamily;
                                  }
                                  return l10n.folioCloudPlanActiveHeadline;
                                }(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: snap.active ? Colors.white : scheme.onSurface,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                () {
                                  if (!snap.active) return l10n.folioCloudSubscriptionNoneSubtitle;
                                  if (snap.isStudent) return '1000 gotas/mes • 15 GB espacio de copias';
                                  if (snap.isFamily) {
                                    if (snap.familyOwnerUid != null) {
                                      return l10n.folioCloudFamilyMemberNote(snap.familyOwnerUid!);
                                    }
                                    return '500 gotas/mes • 5 GB espacio de copias • Admin';
                                  }
                                  return l10n.folioCloudSubscriptionActive;
                                }(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: snap.active
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        membershipChip(
                          icon: Icons.backup_outlined,
                          label: l10n.folioCloudFeatureBackup,
                        ),
                        membershipChip(
                          icon: FolioIcons.quillOutlined,
                          label: l10n.folioCloudFeatureCloudAi,
                        ),
                        membershipChip(
                          icon: Icons.public_outlined,
                          label: l10n.folioCloudFeaturePublishWeb,
                        ),
                      ],
                    ),
                    if (!snap.active) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: busy ? null : onOpenPitch,
                          icon: const Icon(Icons.info_outline, size: 20),
                          label: Text(l10n.folioCloudPitchLearnMore),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (snap.active) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () {
                                      if (snap.isFamily && snap.familyOwnerUid != null) {
                                        final uid = FirebaseAuth.instance.currentUser?.uid;
                                        if (uid != null) {
                                          onRemoveFamilyMember(uid);
                                        }
                                      } else {
                                        onBillingPortal();
                                      }
                                    },
                              icon: Icon(
                                (snap.isFamily && snap.familyOwnerUid != null)
                                    ? Icons.logout_rounded
                                    : Icons.payments_outlined,
                                size: 20,
                              ),
                              label: Text(
                                (snap.isFamily && snap.familyOwnerUid != null)
                                    ? l10n.folioCloudFamilyLeaveButton
                                    : l10n.folioCloudManageSubscription,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: busy ? null : onRefreshBilling,
                            icon: const Icon(Icons.sync, size: 20),
                            label: Text(l10n.folioCloudRefreshFromStripe),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : onSubscribeMonthly,
                            icon: const Icon(Icons.subscriptions_outlined, size: 20),
                            label: Text(l10n.folioCloudSubscribeMonthly),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : (snap.isStudentVerified
                                          ? onSubscribeStudent
                                          : () => _showStudentVerificationDialog(context)),
                                  icon: const Icon(Icons.school_outlined, size: 20),
                                  label: Text(l10n.folioCloudSubscribeStudent),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (snap.isStudentVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verificado',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _showStudentVerificationDialog(context),
                                  child: Text(l10n.folioCloudStudentVerifyButton),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: busy ? null : onRefreshBilling,
                            icon: const Icon(Icons.sync, size: 20),
                            label: Text(l10n.folioCloudRefreshFromStripe),
                          ),
                        ],
                      ),
                    ],
                    if (showMicrosoftStoreBillingNote) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.folioCloudMicrosoftStoreSyncHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (snap.active && snap.familyOwnerUid == null && !snap.isStudent) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FolioRadius.xl),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _FamilyManagerWidget(
                      scheme: scheme,
                      l10n: l10n,
                      snap: snap,
                      onRemoveMember: onRemoveFamilyMember,
                      onInviteMember: onInviteFamilyMember,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Ink shop
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.folioCloudBuyInk,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showInkPricingTable(context),
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    label: Text(l10n.settingsCloudInkViewTableButton),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.settingsCloudInkHostedAiQuillCloudHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 520;
                  final cards = [
                    _FolioCloudInkPackCard(
                      scheme: scheme,
                      title: l10n.folioCloudInkSmall,
                      drops: 300,
                      onPressed: busy ? null : onInkSmall,
                    ),
                    _FolioCloudInkPackCard(
                      scheme: scheme,
                      title: l10n.folioCloudInkMedium,
                      drops: 1000,
                      onPressed: busy ? null : onInkMedium,
                    ),
                    _FolioCloudInkPackCard(
                      scheme: scheme,
                      title: l10n.folioCloudInkLarge,
                      drops: 2500,
                      onPressed: busy ? null : onInkLarge,
                    ),
                  ];
                  if (narrow) {
                    return Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          cards[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionInk,
          scheme: scheme,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardMin = ((constraints.maxWidth - 20) / 3).clamp(
                104.0,
                220.0,
              );
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.calendar_month_outlined,
                    label: l10n.folioCloudInkMonthly,
                    valueText: l10n.folioCloudInkCount(snap.ink.monthlyBalance),
                    minWidth: cardMin,
                  ),
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.shopping_bag_outlined,
                    label: l10n.folioCloudInkPurchased,
                    valueText: l10n.folioCloudInkCount(
                      snap.ink.purchasedBalance,
                    ),
                    minWidth: cardMin,
                  ),
                  _FolioCloudInkStatCard(
                    scheme: scheme,
                    icon: Icons.water_drop_outlined,
                    label: l10n.folioCloudInkTotal,
                    valueText: l10n.folioCloudInkCount(snap.ink.totalInk),
                    minWidth: cardMin,
                  ),
                ],
              );
            },
          ),
        ),
        if (snap.ink.purchasedBalance > 0) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.folioCloudInkPurchaseAppliedHint(
                        l10n.folioCloudInkCount(snap.ink.purchasedBalance),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionEncryptedBackups,
          scheme: scheme,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snap.canUseCloudBackup)
                Text(
                  l10n.folioCloudBackupStorageSectionIntro,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              if (!snap.canUseCloudBackup) ...[
                Text(
                  l10n.settingsCloudBackupsNeedPlan,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (snap.canUseCloudBackup) const SizedBox(height: 10),
              if (snap.canUseCloudBackup && snap.backupExtraBytesTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_box_outlined,
                          size: 22,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.folioCloudBackupStoragePurchasedExtra(
                              fmtStorageBytes(snap.backupExtraBytesTotal),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (!snap.canUseCloudBackup) {
                    return const SizedBox.shrink();
                  }

                  final quota = snap.backupQuotaBytes;
                  final usedBytes = snap.backupUsedBytes;
                  final remainingBytes = quota > 0
                      ? (quota - usedBytes).clamp(0, quota)
                      : 0;
                  final determinate = quota > 0;
                  final usedLabel = determinate
                      ? fmtStorageBytes(usedBytes)
                      : '…';
                  final quotaLabel = determinate ? fmtStorageBytes(quota) : '…';
                  final remainingLabel = determinate
                      ? fmtStorageBytes(remainingBytes)
                      : '…';
                  final pct = determinate
                      ? ((usedBytes / quota) * 100).round().clamp(0, 100)
                      : null;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pie_chart_outline_rounded,
                              size: 22,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.folioCloudBackupStorageBarTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (pct != null)
                              Text(
                                l10n.folioCloudBackupStorageBarPercent(pct),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: scheme.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 26,
                            child: LinearProgressIndicator(
                              value: determinate
                                  ? (usedBytes / quota).clamp(0.0, 1.0)
                                  : null,
                              minHeight: 26,
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                pct != null && pct >= 90
                                    ? scheme.error
                                    : scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          determinate
                              ? l10n.folioCloudBackupStorageBarDetail(
                                  usedLabel,
                                  quotaLabel,
                                  remainingLabel,
                                )
                              : '…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (snap.canUseCloudBackup && snap.active && snap.backup) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.folioCloudBackupStorageExpansionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 520;
                    final cards = [
                      _FolioCloudBackupStorageTierCard(
                        scheme: scheme,
                        title: l10n.folioCloudBackupStorageLibrarySmallTitle,
                        detail: l10n.folioCloudBackupStorageLibrarySmallDetail,
                        onPressed: busy ? null : onBackupStoragePackSmall,
                      ),
                      _FolioCloudBackupStorageTierCard(
                        scheme: scheme,
                        title: l10n.folioCloudBackupStorageLibraryMediumTitle,
                        detail: l10n.folioCloudBackupStorageLibraryMediumDetail,
                        onPressed: busy ? null : onBackupStoragePackMedium,
                      ),
                      _FolioCloudBackupStorageTierCard(
                        scheme: scheme,
                        title: l10n.folioCloudBackupStorageLibraryLargeTitle,
                        detail: l10n.folioCloudBackupStorageLibraryLargeDetail,
                        onPressed: busy ? null : onBackupStoragePackLarge,
                      ),
                    ];
                    if (narrow) {
                      return Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            cards[i],
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (snap.canUseCloudBackup)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
              l10n.folioCloudIncrementalBackupManualHint(
                l10n.vaultBackupRunNowTile,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: Text(l10n.folioCloudCloudBackupsList),
          enabled: !busy && snap.canUseCloudBackup,
          onTap: busy || !snap.canUseCloudBackup ? null : onOpenBackups,
        ),
        _SettingsSubsectionTitle(
          title: l10n.folioCloudSubsectionPublishing,
          scheme: scheme,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.list_alt_outlined),
          title: Text(l10n.folioCloudPublishedPagesList),
          enabled: !busy && snap.canPublishToWeb,
          onTap: busy || !snap.canPublishToWeb ? null : onPublishedPages,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showStudentVerificationDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return FolioDialog(
          title: Row(
            children: [
              Icon(Icons.school_rounded, color: scheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(l10n.folioCloudStudentVerifyDialogTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.folioCloudStudentVerifyDialogDesc,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: l10n.folioCloudStudentVerifyDialogLabel,
                  hintText: l10n.folioCloudStudentVerifyDialogHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.folioCloudStudentVerifyDialogHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final email = controller.text.trim();
                if (email.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  onVerifyStudent(email);
                }
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.folioCloudStudentVerifyDialogAction),
            ),
          ],
        );
      },
    );
  }
}

class _FamilyManagerWidget extends StatefulWidget {
  const _FamilyManagerWidget({
    required this.scheme,
    required this.l10n,
    required this.snap,
    required this.onRemoveMember,
    required this.onInviteMember,
  });

  final ColorScheme scheme;
  final AppLocalizations l10n;
  final FolioCloudSnapshot snap;
  final ValueChanged<String> onRemoveMember;
  final ValueChanged<String> onInviteMember;

  @override
  State<_FamilyManagerWidget> createState() => _FamilyManagerWidgetState();
}

class _FamilyManagerWidgetState extends State<_FamilyManagerWidget> {
  final _emailController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<String> _members = [];
  Map<String, dynamic> _membersInfo = {};

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await callFolioHttpsCallable(
        'getFamilyDetails',
        <String, dynamic>{},
      );
      final map = (res as Map?)?.cast<String, dynamic>() ?? {};
      final members = (map['members'] as List?)?.cast<String>() ?? [];
      final membersInfo =
          (map['membersInfo'] as Map?)?.cast<String, dynamic>() ?? {};

      if (mounted) {
        setState(() {
          _members = members;
          _membersInfo = membersInfo;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline, color: widget.scheme.primary),
            const SizedBox(width: 8),
            Text(
              widget.l10n.folioCloudFamilyTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            if (_error != null) {
              return FolioErrorCard(
                title: 'Error al cargar miembros',
                message: _error!,
                icon: Icons.people_outline,
                onRetry: _loadFamilyData,
              );
            }

            if (_loading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: FolioFamilySeatsSkeleton(),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.l10n.folioCloudFamilyOwnerNote(
                    widget.snap.familySeats,
                    _members.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                if (_members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No hay miembros en tu familia aún.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: widget.scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final mUid = _members[index];
                      final info = _membersInfo[mUid] as Map?;
                      final email = info?['email']?.toString() ?? 'Sin correo';
                      final displayName = info?['displayName']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: widget.scheme.primaryContainer,
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: widget.scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (displayName.isNotEmpty)
                                    Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  Text(
                                    email,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: widget.scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: widget.scheme.error,
                                size: 20,
                              ),
                              onPressed: () async {
                                widget.onRemoveMember(mUid);
                                await Future<void>.delayed(
                                    const Duration(seconds: 1));
                                _loadFamilyData();
                              },
                              tooltip: widget.l10n.folioCloudFamilyRemoveButton,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: widget.l10n.folioCloudFamilyEmailPlaceholder,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          widget.onInviteMember(email);
                          _emailController.clear();
                          await Future<void>.delayed(
                              const Duration(seconds: 1));
                          _loadFamilyData();
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(widget.l10n.folioCloudFamilyInviteButton),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FolioCloudInkStatCard extends StatelessWidget {
  const _FolioCloudInkStatCard({
    required this.scheme,
    required this.icon,
    required this.label,
    required this.valueText,
    required this.minWidth,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String label;
  final String valueText;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valueText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolioCloudInkPackCard extends StatelessWidget {
  const _FolioCloudInkPackCard({
    required this.scheme,
    required this.title,
    required this.drops,
    required this.onPressed,
  });

  final ColorScheme scheme;
  final String title;
  final int drops;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMedium = drops == 1000;
    final isLarge = drops == 2500;
    final isHighlighted = isMedium || isLarge;

    final badgeLabel = isMedium
        ? (Localizations.localeOf(context).languageCode == 'es' ? 'POPULAR' : 'POPULAR')
        : (Localizations.localeOf(context).languageCode == 'es' ? 'MEJOR VALOR' : 'BEST VALUE');

    final cardBorderColor = isLarge
        ? scheme.tertiary.withValues(alpha: 0.5)
        : isMedium
            ? scheme.primary.withValues(alpha: 0.5)
            : scheme.outlineVariant.withValues(alpha: 0.35);

    final cardBgColor = isLarge
        ? scheme.tertiaryContainer.withValues(alpha: 0.15)
        : isMedium
            ? scheme.primaryContainer.withValues(alpha: 0.15)
            : scheme.surface.withValues(alpha: 0.86);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cardBorderColor,
            width: isHighlighted ? 1.5 : 1.0,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: (isLarge ? scheme.tertiary : scheme.primary).withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.opacity_outlined,
                      color: isLarge
                          ? scheme.tertiary
                          : isMedium
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '+$drops',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: scheme.onSurface,
                    height: 1.1,
                  ),
                ),
                Text(
                  'ink',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: onPressed,
                  style: isHighlighted
                      ? FilledButton.styleFrom(
                          backgroundColor: isLarge ? scheme.tertiary : scheme.primary,
                          foregroundColor: isLarge ? scheme.onTertiary : scheme.onPrimary,
                        )
                      : null,
                  child: Text(AppLocalizations.of(context).continueAction),
                ),
              ],
            ),
            if (isHighlighted)
              Positioned(
                top: -24,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLarge ? scheme.tertiary : scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (isLarge ? scheme.tertiary : scheme.primary).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isLarge ? scheme.onTertiary : scheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FolioCloudBackupStorageTierCard extends StatelessWidget {
  const _FolioCloudBackupStorageTierCard({
    required this.scheme,
    required this.title,
    required this.detail,
    required this.onPressed,
  });

  final ColorScheme scheme;
  final String title;
  final String detail;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isMedium = title.toLowerCase().contains('medium') || title.toLowerCase().contains('median');
    
    final cardBorderColor = isMedium
        ? scheme.tertiary.withValues(alpha: 0.5)
        : scheme.outlineVariant.withValues(alpha: 0.35);

    final cardBgColor = isMedium
        ? scheme.tertiaryContainer.withValues(alpha: 0.15)
        : scheme.surface.withValues(alpha: 0.86);

    final badgeLabel = Localizations.localeOf(context).languageCode == 'es' ? 'POPULAR' : 'POPULAR';

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cardBorderColor,
            width: isMedium ? 1.5 : 1.0,
          ),
          boxShadow: isMedium
              ? [
                  BoxShadow(
                    color: scheme.tertiary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_library_outlined,
                      color: isMedium ? scheme.tertiary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  detail,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: onPressed,
                  style: isMedium
                      ? FilledButton.styleFrom(
                          backgroundColor: scheme.tertiary,
                          foregroundColor: scheme.onTertiary,
                        )
                      : null,
                  child: Text(l10n.folioCloudSubscribeBackupStorageAddon),
                ),
              ],
            ),
            if (isMedium)
              Positioned(
                top: -24,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.tertiary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.tertiary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onTertiary,
                      fontWeight: FontWeight.w900,
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



class _SettingsSectionNavItem {
  const _SettingsSectionNavItem({
    required this.id,
    required this.label,
    this.searchExtra = const [],
  });

  final _SettingsSectionId id;
  final String label;
  final List<String> searchExtra;
}

enum _SettingsSectionId {
  cloud,
  vault,
  uiWorkspace,
  ai,
  sync,
  about,
  integrations,
}
