import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../data/database/app_database.dart';
import '../../../providers/profile_providers.dart';

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
    await ref.read(profileRepositoryProvider).addWebsiteRule(
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileByIdProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(title: const Text('Websites')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          final rules = profile?.websites ?? const <WebsiteRule>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavClearance),
            children: [
              Text(
                'Block domains inside the browser URL bar. Works across Chrome, '
                'Firefox, Brave, Samsung and other supported browsers.',
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
                        decoration: const InputDecoration(
                          labelText: 'Domain',
                          hintText: 'e.g. instagram.com',
                          prefixIcon: Icon(Icons.language),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _anywhereInUrl,
                        onChanged: (v) => setState(() => _anywhereInUrl = v),
                        title: const Text('Match anywhere in URL'),
                        subtitle: Text(
                          _anywhereInUrl
                              ? 'Blocks any URL that contains the text'
                              : 'Exact domain match (with subdomains)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
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
                    'No websites blocked yet.',
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
                      child: const Icon(Icons.delete_outline,
                          color: KoruColors.danger),
                    ),
                    onDismissed: (_) => _delete(rule),
                    child: ListTile(
                      leading: const Icon(Icons.language,
                          color: KoruColors.textSecondary),
                      title: Text(rule.name),
                      subtitle: Text(
                        rule.isAnywhereInUrl ? 'Anywhere in URL' : 'Domain match',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: KoruColors.textSecondary,
                            ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: KoruColors.danger),
                        onPressed: () => _delete(rule),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
