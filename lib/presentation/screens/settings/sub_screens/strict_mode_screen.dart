import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../platform/strict_mode_channel.dart';
import '../../../providers/achievements_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';
import '../../../widgets/unlock_challenge_dialog.dart';

class StrictModeScreen extends ConsumerStatefulWidget {
  const StrictModeScreen({super.key});

  @override
  ConsumerState<StrictModeScreen> createState() => _StrictModeScreenState();
}

class _StrictModeScreenState extends ConsumerState<StrictModeScreen> {
  int _mask = 0;
  bool _deviceAdminActive = false;
  bool _loaded = false;

  StrictModeChannel get _channel =>
      ref.read(platformChannelServiceProvider).strictMode;

  Future<void> _hydrate() async {
    if (_loaded) return;
    final mask = await _channel.getStrictModeOptions();
    final admin = await _channel.isDeviceAdminActive();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _mask = mask;
      _deviceAdminActive = admin;
    });
  }

  bool get _isEnabled => _mask != 0;

  /// Chiede la sfida a memoria che autorizza il passaggio a [targetMask].
  ///
  /// Ha SOSTITUITO il backdoor code su questo percorso. Il code resta, ma solo
  /// come emergency unblock (schermata Backdoor): serve quando il puzzle non
  /// basta o non si riesce a risolverlo, e per quello ha senso che costi la
  /// rotazione settimanale.
  ///
  /// Il token che torna è monouso, vale ~60s ed è vincolato a [targetMask]:
  /// una sfida ottenuta per spegnere un bit non autorizza l'uscita completa.
  Future<String?> _requireChallenge(int targetMask, String action) =>
      requireStrictUnlockChallenge(
        context,
        channel: _channel,
        targetMask: targetMask,
        action: action,
      );

  /// Applica [next] e allinea lo stato locale.
  ///
  /// Il native può comunque rifiutare (token scaduto fra la soluzione del
  /// puzzle e la chiamata, o binding sulla mask sbagliato): in quel caso NON
  /// tocchiamo `_mask`, così la UI continua a mostrare la protezione ancora
  /// attiva — che è la verità.
  Future<void> _applyMask(int next, {String? token}) async {
    try {
      await _channel.setStrictModeOptions(next, unblockToken: token);
      if (!mounted) return;
      setState(() => _mask = next);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = e.code == 'UNAUTHORIZED'
          ? l10n.strictModeVerificationExpired
          : l10n.strictModeApplyFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _toggleOption(int bit, bool enabled) async {
    final next = enabled ? (_mask | bit) : (_mask & ~bit);
    if (enabled || (_mask & bit) == 0) {
      // ALZARE la mask non richiede nulla: è la direzione fail-secure.
      return _applyMask(next);
    }
    final token = await _requireChallenge(
      next,
      AppLocalizations.of(context).strictModeActionRemoveRestriction,
    );
    if (token == null) return; // annullato / non autorizzato
    await _applyMask(next, token: token);
  }

  Future<void> _toggleMaster(bool on) async {
    if (on) {
      if (!_deviceAdminActive) {
        await _channel.enableDeviceAdmin();
        // User returns: recheck status when screen resumes.
      }
      await _channel.setStrictModeOptions(StrictModeOption.allMvp);
      if (!mounted) return;
      setState(() => _mask = StrictModeOption.allMvp);
      await ref.read(achievementEvaluationProvider.notifier).trigger();
    } else {
      // L'uscita completa è l'azione più grave: il native lo sa (glielo dice
      // targetMask=0) e serve una sfida più lunga, con meno tempo per
      // guardarla.
      final token = await _requireChallenge(
        0,
        AppLocalizations.of(context).strictModeActionTurnOff,
      );
      if (token == null) return;
      await _applyMask(0, token: token);
    }
  }

  Future<void> _disableDeviceAdmin() async {
    try {
      await _channel.disableDeviceAdmin();
      if (!mounted) return;
      setState(() => _deviceAdminActive = false);
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'STRICT_ACTIVE') {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx).strictModeActiveDialogTitle),
            content: Text(AppLocalizations.of(ctx).strictModeActiveDialogBody),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(ctx).commonOk),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // Niente scorciatoia al backdoor code qui: da quando il downgrade passa
      // dalla sfida a memoria, un pulsante "Backdoor" in cima alla schermata
      // si legge come "la via d'uscita normale, ma senza puzzle" — cioè
      // esattamente il contrario di quello che è. Lo sblocco d'emergenza vive
      // in fondo alle Impostazioni.
      appBar: AppBar(title: Text(l10n.strictModeTitle)),
      body: KoruPullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: _isEnabled ? KoruColors.dangerContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEnabled ? Icons.lock : Icons.lock_open,
                          color: _isEnabled
                              ? KoruColors.danger
                              : KoruColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isEnabled
                                ? l10n.strictModeStatusOn
                                : l10n.strictModeStatusOff,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(value: _isEnabled, onChanged: _toggleMaster),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEnabled
                          ? l10n.strictModeDescriptionOn
                          : l10n.strictModeDescriptionOff,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KoruColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(l10n.strictModeWhatToLock),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mask & StrictModeOption.blockSettings != 0,
              onChanged: (v) =>
                  _toggleOption(StrictModeOption.blockSettings, v),
              title: Text(l10n.strictModeBlockSettings),
              subtitle: Text(l10n.strictModeBlockSettingsSubtitle),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mask & StrictModeOption.blockRecentApps != 0,
              onChanged: (v) =>
                  _toggleOption(StrictModeOption.blockRecentApps, v),
              title: Text(l10n.strictModeBlockRecents),
              subtitle: Text(l10n.strictModeBlockRecentsSubtitle),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mask & StrictModeOption.blockUninstalling != 0,
              onChanged: (v) =>
                  _toggleOption(StrictModeOption.blockUninstalling, v),
              title: Text(l10n.strictModeBlockUninstall),
              subtitle: Text(l10n.strictModeBlockUninstallSubtitle),
            ),
            const SizedBox(height: 24),
            _SectionTitle(l10n.strictModeDeviceAdmin),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _deviceAdminActive
                    ? Icons.verified
                    : Icons.warning_amber_outlined,
                color: _deviceAdminActive
                    ? KoruColors.success
                    : KoruColors.secondary,
              ),
              title: Text(
                _deviceAdminActive
                    ? l10n.strictModeDeviceAdminActive
                    : l10n.strictModeDeviceAdminRequired,
              ),
              subtitle: Text(
                _deviceAdminActive
                    ? l10n.strictModeDeviceAdminActiveSubtitle
                    : l10n.strictModeDeviceAdminRequiredSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KoruColors.textSecondary,
                ),
              ),
              trailing: _deviceAdminActive
                  ? TextButton(
                      onPressed: _disableDeviceAdmin,
                      child: Text(l10n.commonDisable),
                    )
                  : FilledButton(
                      onPressed: () async {
                        await _channel.enableDeviceAdmin();
                      },
                      child: Text(l10n.commonEnable),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: KoruColors.textSecondary,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
