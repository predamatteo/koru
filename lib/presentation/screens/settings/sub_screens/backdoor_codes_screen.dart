import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../platform/strict_mode_channel.dart';

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
  bool _loaded = false;

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
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _currentCode = code;
    });
  }

  Future<void> _validate() async {
    final input = _codeController.text.trim();
    if (input.isEmpty) return;
    final ok = await _channel.validateBackdoorCode(input);
    if (!mounted) return;
    if (ok) {
      await _channel.performEmergencyUnblock();
      setState(() => _validationResult = 'Valid — Strict mode turned off.');
    } else {
      setState(() => _validationResult = 'Invalid code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) _hydrate();

    return Scaffold(
      appBar: AppBar(title: const Text('Backdoor codes')),
      body: ListView(
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
                  SelectableText(
                    _currentCode ?? '••••••••',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Orbitron',
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Copy it somewhere safe. It changes every week based on '
                    'your device ID, works offline, and is single-use.',
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
          Text(
            'Emergency unblock',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Enter code',
              hintText: 'ABC123…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _validate,
            child: const Text('Unlock'),
          ),
          if (_validationResult != null) ...[
            const SizedBox(height: 12),
            Text(
              _validationResult!,
              style: TextStyle(
                color: _validationResult!.startsWith('Valid')
                    ? KoruColors.success
                    : KoruColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
