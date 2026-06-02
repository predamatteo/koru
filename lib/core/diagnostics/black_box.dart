import 'package:flutter/services.dart';

/// Wrapper Dart della scatola nera nativa (`BlackBox` Kotlin via il channel
/// `com.koru/blackbox`). Scrive sullo STESSO file persistente dei segnali
/// nativi, cosi' la timeline lato Flutter (load della lista app, primo emit dei
/// preferiti, decisioni del resume handler) si correla a quella nativa (cold
/// start, pressione memoria, stall Keystore).
///
/// Differenza chiave rispetto a `debugPrint`/`developer.log`: questa
/// SOPRAVVIVE al kill del processo (file su disco) e funziona in **release** (il
/// channel nativo non e' gated su debug). Si recupera con
/// `adb pull /sdcard/Android/data/com.dev.koru/files/koru_blackbox.log`.
///
/// Fire-and-forget by design: un fallimento del log (channel non ancora pronto
/// al primissimo frame di cold start, engine in teardown) viene ingoiato e non
/// deve MAI propagarsi al chiamante.
class BlackBox {
  BlackBox._();

  static const MethodChannel _channel = MethodChannel('com.koru/blackbox');

  /// Accoda una riga sulla scatola nera. Non attende il completamento.
  static void log(String tag, String msg) {
    // ignore: discarded_futures — fire-and-forget intenzionale.
    _channel
        .invokeMethod<void>('log', {'tag': tag, 'msg': msg})
        .catchError((Object _) {});
  }

  /// Path assoluto del file di log sul device (per mostrarlo in una eventuale
  /// schermata di diagnostica / istruzioni di pull). `null` se il channel
  /// nativo non e' raggiungibile.
  static Future<String?> path() async {
    try {
      return await _channel.invokeMethod<String>('path');
    } catch (_) {
      return null;
    }
  }
}
