import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../data/database/app_database.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../providers/profile_providers.dart';
import '../../../widgets/koru_pull_to_refresh.dart';
import '../../../widgets/unlock_challenge_dialog.dart';

/// Editor delle regole website bloccate per un profilo. Le regole vengono
/// matchate dal nativo AccessibilityService leggendo la URL bar dei browser
/// supportati (Chrome, Firefox, Brave, Samsung, Opera, ecc.).
class WebsitesScreen extends ConsumerStatefulWidget {
  const WebsitesScreen({super.key, required this.profileId});

  final int profileId;

  @override
  ConsumerState<WebsitesScreen> createState() => _WebsitesScreenState();
}

class _WebsitesScreenState extends ConsumerState<WebsitesScreen> {
  final _domainController = TextEditingController();
  bool _anywhereInUrl = false;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  String _normalize(String raw) {
    var v = raw.trim().toLowerCase();
    if (v.startsWith('http://')) v = v.substring(7);
    if (v.startsWith('https://')) v = v.substring(8);
    if (v.startsWith('www.')) v = v.substring(4);
    if (v.endsWith('/')) v = v.substring(0, v.length - 1);
    return v;
  }

  Future<void> _add() async {
    final name = _normalize(_domainController.text);
    if (name.isEmpty) return;
    await ref
        .read(profileRepositoryProvider)
        .addWebsiteRule(
          profileId: widget.profileId,
          name: name,
          blockingType: _anywhereInUrl ? 1 : 0,
          isAnywhereInUrl: _anywhereInUrl,
        );
    _domainController.clear();
    setState(() => _anywhereInUrl = false);
    ref.invalidate(profileByIdProvider(widget.profileId));
  }

  Future<void> _delete(WebsiteRule rule) async {
    await ref
        .read(profileRepositoryProvider)
        .deleteWebsiteRule(rule.id, widget.profileId);
    ref.invalidate(profileByIdProvider(widget.profileId));
  }

  /// Togliere un sito da un profilo ACCESO allenta la protezione esattamente
  /// come toglierne un'app: stessa sfida di sblocco. Aggiungerne resta libero,
  /// e su un profilo spento non c'è niente da allentare.
  ///
  /// È anche il `confirmDismiss` dello swipe: gestire il gate in `onDismissed`
  /// non funzionerebbe, lì la riga è già sparita dalla lista e annullare la
  /// sfida la lascerebbe invisibile pur essendo ancora in DB.
  Future<bool> _confirmRemoval(bool profileEnabled) async {
    if (!profileEnabled) return true;
    return requireUnlockChallenge(
      context,
      ref,
      action: AppLocalizations.of(context).websitesActionRemove,
    );
  }

  Future<void> _deleteWithGate(WebsiteRule rule, bool profileEnabled) async {
    if (!await _confirmRemoval(profileEnabled)) return;
    await _delete(rule);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileByIdProvider(widget.profileId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEditorSectionWebsites)),
      body: KoruPullToRefresh(
        onRefresh: () async =>
            ref.invalidate(profileByIdProvider(widget.profileId)),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (profile) {
            final rules = profile?.websites ?? const <WebsiteRule>[];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                kBottomNavClearance,
              ),
              children: [
                Text(
                  l10n.websitesIntro,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoruColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: KoruColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _domainController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                          decoration: InputDecoration(
                            labelText: l10n.websitesDomainLabel,
                            hintText: l10n.websitesDomainHint,
                            prefixIcon: const Icon(Icons.language),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _anywhereInUrl,
                          onChanged: (v) => setState(() => _anywhereInUrl = v),
                          title: Text(l10n.websitesMatchAnywhere),
                          subtitle: Text(
                            _anywhereInUrl
                                ? l10n.websitesMatchAnywhereOn
                                : l10n.websitesMatchAnywhereOff,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.commonAdd),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.websitesEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KoruColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...rules.map(
                    (rule) => Dismissible(
                      key: ValueKey('rule-${rule.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: KoruColors.dangerContainer,
                        child: const Icon(
                          Icons.delete_outline,
                          color: KoruColors.danger,
                        ),
                      ),
                      confirmDismiss: (_) =>
                          _confirmRemoval(profile?.isEnabled ?? false),
                      onDismissed: (_) => _delete(rule),
                      child: ListTile(
                        leading: const Icon(
                          Icons.language,
                          color: KoruColors.textSecondary,
                        ),
                        title: Text(rule.name),
                        subtitle: Text(
                          rule.isAnywhereInUrl
                              ? l10n.websitesRuleAnywhere
                              : l10n.websitesRuleDomain,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: KoruColors.textSecondary),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: KoruColors.danger,
                          ),
                          onPressed: () =>
                              _deleteWithGate(rule, profile?.isEnabled ?? false),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
