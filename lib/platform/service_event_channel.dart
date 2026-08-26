import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Eventi emessi dal native service al Flutter tramite EventChannel.
sealed class KoruServiceEvent {
  const KoruServiceEvent();

  factory KoruServiceEvent.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'SERVICE_STATE':
        return ServiceStateEvent(running: json['running'] as bool? ?? false);
      case 'BLOCKING_STATE':
        return BlockingStateEvent(
          isBlocking: json['isBlocking'] as bool? ?? false,
          packageName: json['packageName'] as String? ?? '',
          profileId: json['profileId'] as int? ?? -1,
          profileTitle: json['profileTitle'] as String? ?? '',
        );
      case 'PACKAGE_CHANGED':
        return PackageChangedEvent(
          kind: json['kind'] as String? ?? '',
          packageName: json['packageName'] as String? ?? '',
        );
      case 'OPEN_APPS_COUNT':
        return OpenAppsCountEvent(
          count: (json['count'] as num?)?.toInt() ?? 0,
          seq: (json['seq'] as num?)?.toInt() ?? 0,
        );
      default:
        return UnknownServiceEvent(raw: json);
    }
  }
}

class ServiceStateEvent extends KoruServiceEvent {
  const ServiceStateEvent({required this.running});
  final bool running;
}

class BlockingStateEvent extends KoruServiceEvent {
  const BlockingStateEvent({
    required this.isBlocking,
    required this.packageName,
    required this.profileId,
    required this.profileTitle,
  });
  final bool isBlocking;
  final String packageName;
  final int profileId;
  final String profileTitle;
}

class PackageChangedEvent extends KoruServiceEvent {
  const PackageChangedEvent({required this.kind, required this.packageName});
  /// 'added' | 'removed' | 'replaced'
  final String kind;
  final String packageName;
}

/// Push del contatore "schede aperte" dal nativo (OpenAppsTracker): emesso
/// ogni volta che il set cambia (sync con le card reali, reset, uninstall,
/// noteForeground). Il badge del launcher si aggiorna senza round-trip.
class OpenAppsCountEvent extends KoruServiceEvent {
  const OpenAppsCountEvent({required this.count, required this.seq});
  final int count;

  /// Sequence number monotono della mutazione nativa: il provider scarta i
  /// payload con seq più vecchio di quello già applicato (anti-race con il
  /// pull di getOpenAppsCount).
  final int seq;
}

class UnknownServiceEvent extends KoruServiceEvent {
  const UnknownServiceEvent({required this.raw});
  final Map<String, dynamic> raw;
}

class ServiceEventChannel {
  ServiceEventChannel();

  static const EventChannel _channel = EventChannel('com.koru/service_events');

  // PERF/correttezza: un SOLO upstream condiviso verso l'EventChannel.
  //
  // `receiveBroadcastStream()` registra il proprio handler keyed sul SOLO nome
  // del canale: l'engine Flutter (e il lato Kotlin con un unico `eventSink`)
  // tiene UN solo listener per canale, e impostare un nuovo listener cancella
  // il precedente. Con più subscriber (blocking refresher, package refresher,
  // achievement evaluator) ognuno che chiamava
  // `receiveBroadcastStream()` clobberava la registrazione degli altri: solo
  // l'ultimo riceveva gli eventi e lo smontaggio di uno chiudeva il canale per
  // tutti → eventi persi/duplicati e "reload casuali" dei provider.
  //
  // Soluzione: una sola subscription upstream (mai cancellata per la vita
  // dell'app — `PlatformChannelService` è un singleton non-autoDispose) che fa
  // fan-out via un [StreamController.broadcast]. I subscriber si attaccano al
  // broadcast; cancellare la propria subscription NON tocca l'upstream.
  StreamController<KoruServiceEvent>? _controller;

  Stream<KoruServiceEvent> events() {
    final existing = _controller;
    if (existing != null && !existing.isClosed) return existing.stream;
    final controller = StreamController<KoruServiceEvent>.broadcast();
    _controller = controller;
    // Una sola subscription upstream per la vita dell'app. Non la teniamo in un
    // campo: una subscription attiva resta viva finché lo stream broadcast del
    // canale è vivo (non viene GC-ata) e non la cancelliamo mai di proposito.
    _channel.receiveBroadcastStream().listen(
      (raw) => controller.add(_decode(raw)),
      onError: controller.addError,
      // L'EventChannel reale non termina mai; onDone serve ai test
      // (MockStreamHandler.endOfStream) per far completare `events().toList()`.
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );
    return controller.stream;
  }

  static KoruServiceEvent _decode(dynamic raw) {
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return KoruServiceEvent.fromJson(decoded);
      }
    }
    return UnknownServiceEvent(raw: {'raw': raw});
  }
}
