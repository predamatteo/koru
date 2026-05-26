import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/strict_mode_channel.dart';
import '../../../widgets/koru_pull_to_refresh.dart';

class BackdoorCodesScreen extends ConsumerStatefulWidget {
  const BackdoorCodesScreen({super.key});

  @override
  ConsumerState<BackdoorCodesScreen> createState() =>
      _BackdoorCodesScreenState();
}

class _BackdoorCodesScreenState extends ConsumerState<BackdoorCodesScreen> {
  final _codeController = TextEditingController();
  String? _currentCode;
  String? _validationResult;
  Color _resultColor = KoruColors.danger;
  int _attemptsLeft = 0;
  int _lockoutRemainingMs = 0;
  bool _loaded = false;
  bool _submitting = false;

  /// SEC-10: il native non può emettere un codice (Keystore non disponibile).
  /// Mostriamo "temporaneamente non disponibile, riprova" invece di un codice
  /// fittizio o, peggio, uno deterministico indovinabile.
  bool _codeUnavailable = false;

  StrictModeChannel get _channel =>
      ref.read(platformChannelServiceProvider).strictMode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_loaded) return;
    final code = await _channel.generateBackdoorCode();
    final attempts = await _channel.getRemainingAttempts();
    final lockout = await _channel.getLockoutRemainingMs();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _currentCode = code;
      _codeUnavailable = code == null;
      _attemptsLeft = attempts;
      _lockoutRemainingMs = lockout;
    });
  }

  Future<void> _refreshCounters() async {
    final attempts = await _channel.getRemainingAttempts();
    final lockout = await _channel.getLockoutRemainingMs();
    if (!mounted) return;
    setState(() {
      _attemptsLeft = attempts;
      _lockoutRemainingMs = lockout;
    });
  }

  Future<void> _validate() async {
    final input = _codeController.text.trim();
    if (input.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _validationResult = null;
    });
    try {
      // Nuovo flow: performEmergencyUnblock fa tutto atomicamente
      // (validate + markUsed + setMask(0) + removeDeviceAdmin). Non
      // chiamiamo più validateBackdoorCode separatamente: era una
      // race condition (un attacker poteva reusare il code tra validate
      // e unblock).
      final outcome = await _channel.performEmergencyUnblock(input);
      if (!mounted) return;
      switch (outcome) {
        case BackdoorValid():
          _codeController.clear();
          setState(() {
            _validationResult =
                'Codice valido — strict mode disattivato. Il codice è stato '
                'consumato; ne sarà generato uno nuovo.';
            _resultColor = KoruColors.success;
          });
          // Refresh del code corrente: dopo emergency unblock il Kotlin
          // ruota il code automaticamente.
          final newCode = await _channel.generateBackdoorCode();
          if (!mounted) return;
          setState(() {
            _currentCode = newCode;
            _codeUnavailable = newCode == null;
          });
        case BackdoorInvalid():
          setState(() {
            _validationResult = 'Codice non valido.';
            _resultColor = KoruColors.danger;
          });
        case BackdoorReplay():
          setState(() {
            _validationResult =
                'Codice già usato. Aspetta la rotazione settimanale per '
                'ricevere un nuovo codice.';
            _resultColor = KoruColors.danger;
          });
        case BackdoorLocked(:final remainingMs):
          setState(() {
            _validationResult = _formatLockoutMessage(remainingMs);
            _resultColor = KoruColors.danger;
            _lockoutRemainingMs = remainingMs;
          });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _validationResult = 'Errore: ${e.message ?? e.code}';
        _resultColor = KoruColors.danger;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        await _refreshCounters();
      }
    }
  }

  String _formatLockoutMessage(int ms) {
    final minutes = (ms / 60000).ceil();
    if (minutes < 60) return 'Lockout: $minutes minuti rimanenti.';
    final hours = (minutes / 60).ceil();
    if (hours < 24) return 'Lockout: $hours ore rimanenti.';
    final days = (hours / 24).ceil();
    return 'Lockout: $days giorni rimanenti.';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();

    final inLockout = _lockoutRemainingMs > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Backdoor codes')),
      body: KoruPullToRefresh(
        onRefresh: _refreshCounters,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: KoruColors.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your current weekly code',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    // SEC-10: se il native non può emettere un codice (Keystore
                    // non disponibile) non mostriamo un codice fittizio —
                    // segnaliamo lo stato e invitiamo a riprovare.
                    if (_codeUnavailable) ...[
                      Text(
                        'Codice temporaneamente non disponibile',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: KoruColors.danger),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lo spazio sicuro del dispositivo (Keystore) non è '
                        'raggiungibile in questo momento, quindi non possiamo '
                        'generare il codice settimanale. Riprova tra poco o '
                        'riavvia il dispositivo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KoruColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ] else ...[
                      SelectableText(
                        _currentCode ?? '••••••••',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Copia il codice in un posto sicuro. Ruota ogni '
                        'settimana, è generato in modo casuale sul tuo '
                        'dispositivo, funziona offline, e ogni codice è '
                        'single-use: appena lo usi per sbloccare lo strict '
                        'mode viene sostituito da uno nuovo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KoruColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Emergency unblock',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              enabled: !inLockout && !_submitting,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(
                labelText: 'Inserisci il codice',
                hintText: 'ABCD2345',
                helperText: inLockout
                    ? _formatLockoutMessage(_lockoutRemainingMs)
                    : '$_attemptsLeft tentativi rimanenti prima del lockout',
                helperStyle: TextStyle(
                  color: inLockout
                      ? KoruColors.danger
                      : (_attemptsLeft <= 1
                            ? KoruColors.danger
                            : KoruColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (inLockout || _submitting) ? null : _validate,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sblocca'),
            ),
            if (_validationResult != null) ...[
              const SizedBox(height: 12),
              Text(_validationResult!, style: TextStyle(color: _resultColor)),
            ],
          ],
        ),
      ),
    );
  }
}
