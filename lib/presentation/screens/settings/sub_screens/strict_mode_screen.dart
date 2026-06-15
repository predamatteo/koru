import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/strict_mode_channel.dart';
import '../../../providers/achievements_provider.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

class StrictModeScreen extends ConsumerStatefulWidget {
  const StrictModeScreen({super.key});

  @override
  ConsumerState<StrictModeScreen> createState() => _StrictModeScreenState();
}

class _StrictModeScreenState extends ConsumerState<StrictModeScreen> {
  int _mask = 0;
  bool _deviceAdminActive = false;
  bool _loaded = false;

  // Posseduto dallo State (non creato/distrutto per ogni apertura del dialog):
  // disporlo subito dopo `await showDialog` lo distruggeva mentre il TextField
  // era ancora montato durante l'animazione di uscita → "used after disposed".
  final TextEditingController _backdoorController = TextEditingController();

  @override
  void dispose() {
    _backdoorController.dispose();
    super.dispose();
  }

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

  /// Richiede backdoor code prima di applicare un cambio che ALLENTA la
  /// protezione (disable master, disable di un singolo bit). Restituisce il
  /// token monouso (SEC-01) se l'utente ha autenticato correttamente, oppure
  /// `null` se ha annullato / fallito / è in lockout.
  ///
  /// Strategia: chiediamo conferma di intent + backdoor code in un dialog
  /// unico. La chiamata al channel performa la validazione atomica (S4):
  /// rate limit, replay check, match. Se passa, il native emette un token
  /// monouso che ritorniamo qui e il caller passa a setStrictModeOptions per
  /// autorizzare il downgrade della mask.
  Future<String?> _requireBackdoorAuth({required String purpose}) async {
    final controller = _backdoorController..clear();
    var attemptsLeft = await _channel.getRemainingAttempts();
    final lockoutMs = await _channel.getLockoutRemainingMs();
    if (!mounted) return null;

    if (lockoutMs > 0) {
      // Lockout attivo: nemmeno mostriamo il dialog, comunichiamo il tempo
      // di attesa.
      await _showLockoutDialog(lockoutMs);
      return null;
    }

    final granted = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              // scrollable: il content contiene un TextField; senza questo
              // l'AlertDialog forza il calcolo dell'altezza intrinseca e va in
              // overflow su schermi piccoli o quando appare la tastiera.
              scrollable: true,
              title: const Text('Conferma con backdoor code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per $purpose devi inserire il backdoor code della '
                    'settimana. Lo trovi in Strict mode → Backdoor.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Backdoor code',
                      hintText: 'ABCD2345',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$attemptsLeft tentativi rimanenti prima del lockout.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: KoruColors.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  // pop() con null: il dialog è Route<String>, ritornare un
                  // bool farebbe `false as String?` → TypeError dentro il
                  // Navigator e ne corromperebbe lo stato (freeze dopo 2-3
                  // annullamenti). null = annullato, come da contratto sotto.
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    final input = controller.text.trim();
                    if (input.isEmpty) {
                      setLocal(() => errorText = 'Codice obbligatorio');
                      return;
                    }
                    final outcome = await _channel.validateBackdoorCode(input);
                    if (!ctx.mounted) return;
                    switch (outcome) {
                      case BackdoorValid(:final unblockToken):
                        Navigator.of(ctx).pop(unblockToken ?? '');
                      case BackdoorInvalid():
                        attemptsLeft = await _channel.getRemainingAttempts();
                        if (!ctx.mounted) return;
                        setLocal(() => errorText = 'Codice non valido');
                      case BackdoorReplay():
                        setLocal(
                          () => errorText =
                              'Codice già usato — aspetta la rotazione settimanale.',
                        );
                      case BackdoorLocked(:final remainingMs):
                        // Stesso motivo dell'Annulla: pop() con null, non false.
                        Navigator.of(ctx).pop();
                        await _showLockoutDialog(remainingMs);
                    }
                  },
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        );
      },
    );

    // Il controller è posseduto dallo State e viene riusato/clearato alla
    // prossima apertura; lo disponiamo in dispose(), non qui (vedi sopra).
    // `granted` è: null = annullato/dismissed; '' = validato ma il native non
    // ha emesso token (fallback); altrimenti il token monouso. Distinguere
    // null da '' permette ai caller di sapere se procedere col downgrade.
    return granted;
  }

  Future<void> _showLockoutDialog(int remainingMs) async {
    if (!mounted) return;
    final minutes = (remainingMs / 60000).ceil();
    final text = minutes < 60
        ? '$minutes minuti'
        : minutes < 24 * 60
        ? '${(minutes / 60).ceil()} ore'
        : '${(minutes / (60 * 24)).ceil()} giorni';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Troppi tentativi falliti'),
        content: Text(
          'Per motivi di sicurezza il backdoor code è disattivato '
          'per $text. Riprova tra un po\'.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOption(int bit, bool enabled) async {
    String? token;
    if (!enabled && (_mask & bit) != 0) {
      // Disabilito un bit attivo (downgrade) → richiedi auth + token (SEC-01).
      token = await _requireBackdoorAuth(
        purpose: 'disattivare questa protezione',
      );
      if (token == null) return; // annullato / lockout / fallito
    }
    final next = enabled ? (_mask | bit) : (_mask & ~bit);
    // ALZARE un bit non richiede token; abbassarlo lo passa (il native lo
    // esige solo per i downgrade).
    await _channel.setStrictModeOptions(next, unblockToken: token);
    if (!mounted) return;
    setState(() => _mask = next);
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
      // Disable master richiede backdoor code (è il path "voglio uscire"
      // più frequente — passa dalla validazione di sicurezza completa).
      final token = await _requireBackdoorAuth(
        purpose: 'disattivare strict mode',
      );
      if (token == null) return; // annullato / lockout / fallito
      // Azzerare la mask è un downgrade: SEC-01 esige il token monouso che
      // _requireBackdoorAuth ha appena ottenuto dal native dopo la validazione
      // del code. Il native lo consuma atomicamente.
      await _channel.setStrictModeOptions(0, unblockToken: token);
      if (!mounted) return;
      setState(() => _mask = 0);
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
            title: const Text('Strict mode attivo'),
            content: const Text(
              'Per disabilitare Device Admin devi prima disattivare '
              'strict mode usando il backdoor code.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/settings/backdoor');
                },
                child: const Text('Apri backdoor'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strict mode'),
        actions: [
          TextButton(
            onPressed: () => context.push('/settings/backdoor'),
            child: const Text('Backdoor'),
          ),
        ],
      ),
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
                                ? 'Strict mode is ON'
                                : 'Strict mode is OFF',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(value: _isEnabled, onChanged: _toggleMaster),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEnabled
                          ? 'Settings, Recent apps and Uninstall are blocked from here. To disable, you will need your weekly backdoor code.'
                          : 'Enable to make Settings, Recent apps and Uninstall harder to reach (a deterrent, not an unbreakable lock). Requires Device Admin.',
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
            _SectionTitle('What to block'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mask & StrictModeOption.blockSettings != 0,
              onChanged: (v) =>
                  _toggleOption(StrictModeOption.blockSettings, v),
              title: const Text('Block Settings'),
              subtitle: const Text(
                'Makes opening the Android Settings app harder (intercepts it via the Accessibility service).',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mask & StrictModeOption.blockRecentApps != 0,
              onChanged: (v) =>
                  _toggleOption(StrictModeOption.blockRecentApps, v),
              title: const Text('Block Recent apps'),
              subtitle: const Text(
                'Makes opening the Recent apps view harder (intercepts it via the Accessibility service).',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mask & StrictModeOption.blockUninstalling != 0,
              onChanged: (v) =>
                  _toggleOption(StrictModeOption.blockUninstalling, v),
              title: const Text('Block Uninstall'),
              subtitle: const Text(
                'Makes uninstalling Koru harder. No app can fully prevent uninstall without Device Owner mode.',
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Device Admin'),
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
                    ? 'Device Admin active'
                    : 'Device Admin required',
              ),
              subtitle: Text(
                _deviceAdminActive
                    ? 'Koru has the permissions it needs.'
                    : 'Koru needs Device Admin to enforce Strict Mode.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KoruColors.textSecondary,
                ),
              ),
              trailing: _deviceAdminActive
                  ? TextButton(
                      onPressed: _disableDeviceAdmin,
                      child: const Text('Disable'),
                    )
                  : FilledButton(
                      onPressed: () async {
                        await _channel.enableDeviceAdmin();
                      },
                      child: const Text('Enable'),
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
