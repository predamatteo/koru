import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/koru_colors.dart';
import '../providers/global_refresh.dart';

/// Pull-to-refresh standard di Koru.
///
/// Avvolge un [child] scrollabile in un [RefreshIndicator] stilizzato con i
/// colori dell'app. Il gesto rinfresca TUTTI i dati dell'app via
/// [refreshAllKoruData] — così l'utente può sbloccare dati "freezati" da
/// qualsiasi schermata, indipendentemente da cosa quella schermata mostri.
///
/// Il [child] dev'essere uno scrollable che accetta l'overscroll anche
/// quando il contenuto è corto: usa `physics: const
/// AlwaysScrollableScrollPhysics()` sul tuo `ListView` / `CustomScrollView`
/// / `SingleChildScrollView`, altrimenti il gesto di pull non parte.
///
/// [onRefresh] opzionale viene eseguito PRIMA del refresh globale (per
/// schermate che devono anche rinfrescare uno stato locale, es. un re-check
/// di permesso fatto via platform channel diretto).
class KoruPullToRefresh extends ConsumerWidget {
  const KoruPullToRefresh({
    required this.child,
    this.onRefresh,
    this.refreshOverride,
    super.key,
  });

  final Widget child;
  final Future<void> Function()? onRefresh;

  /// Se fornito, SOSTITUISCE il refresh globale [refreshAllKoruData]: solo i
  /// provider scelti dal chiamante vengono rinfrescati. Usato dal drawer "All
  /// apps", che deve rinfrescare SOLO l'inventario app (già auto-rinfrescato da
  /// PACKAGE_*/resume) invece di invalidare ~28 provider a ogni pull.
  final Future<void> Function(WidgetRef ref)? refreshOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: KoruColors.primary,
      backgroundColor: KoruColors.surfaceElevated,
      onRefresh: () async {
        await onRefresh?.call();
        final override = refreshOverride;
        if (override != null) {
          await override(ref);
        } else {
          await refreshAllKoruData(ref);
        }
      },
      child: child,
    );
  }
}

/// Avvolge un contenuto corto / non scrollabile (messaggio "lista vuota",
/// stato d'errore, schermata con poche righe) in uno scrollable alto quanto
/// il viewport.
///
/// Serve perché [RefreshIndicator] aggancia il gesto di pull solo a uno
/// scrollable che accetta l'overscroll: senza abbastanza contenuto da
/// scorrere, il pull non partirebbe. Usalo come `child` di
/// [KoruPullToRefresh] negli stati `loading` / `error` / `empty`.
class KoruRefreshableViewport extends StatelessWidget {
  const KoruRefreshableViewport({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
