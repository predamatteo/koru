import 'dart:async';

import 'package:flutter/widgets.dart';

/// Ricostruisce [builder] con l'ora corrente, **una sola volta al minuto**.
///
/// Un `Timer.periodic(1s)` costerebbe ~60 rebuild al minuto per un contenuto
/// che cambia solo al confine dei minuti (l'orologio è `HH:mm`). Qui il timer
/// è armato sul prossimo confine di minuto esatto e si ri-arma da solo dopo
/// ogni tick: un frame al minuto, zero deriva accumulata.
///
/// A processo sospeso i timer non avanzano in modo affidabile: al `resumed`
/// ricalcoliamo e ri-schedultiamo, così tornare sul launcher non mostra mai
/// un'ora vecchia.
class MinuteTickBuilder extends StatefulWidget {
  const MinuteTickBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<MinuteTickBuilder> createState() => _MinuteTickBuilderState();
}

class _MinuteTickBuilderState extends State<MinuteTickBuilder>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final next =
        DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    var delay = next.difference(now);
    if (delay <= Duration.zero) delay = const Duration(minutes: 1);
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
