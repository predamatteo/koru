import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Guida di recovery in-app per chi resta "bloccato" da Strict Mode.
///
/// Mostra gli step INLINE (funziona anche offline / da bloccato, quando un
/// link web potrebbe non bastare) + un bottone opzionale alla guida completa
/// su GitHub. Condivisa fra Strict mode screen e Permissions screen così non
/// divergono. Coerente con [SECURITY.md]/[SUPPORT.md]: Strict Mode è un
/// deterrente, quindi una via d'uscita esiste sempre.
const String _supportUrl =
    'https://github.com/predamatteo/koru/blob/main/SUPPORT.md';

Future<void> showStrictModeRecoveryHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Stuck? How to get back in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Strict Mode is a deterrent, not an unbreakable lock — you can '
              'always get back in:',
            ),
            SizedBox(height: 12),
            _Step(
              n: '1',
              text: 'Use your weekly backdoor code in Settings → Strict mode '
                  'to turn it off.',
            ),
            _Step(
              n: '2',
              text: 'If Accessibility is off, Strict Mode is not enforcing — '
                  'uninstall Koru from system Settings → Apps → Koru.',
            ),
            _Step(
              n: '3',
              text: 'Last resort, from a computer with USB debugging:\n'
                  'adb shell dpm remove-active-admin '
                  'com.dev.koru/com.dev.koru.strictmode.KoruDeviceAdminReceiver\n'
                  'adb shell pm uninstall com.dev.koru',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _openGuide(ctx),
          child: const Text('Full guide'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _openGuide(BuildContext context) async {
  final uri = Uri.parse(_supportUrl);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Offline o nessun browser: gli step inline sopra restano la via
    // primaria, quindi un fallimento qui non lascia l'utente senza recovery.
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n. ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
