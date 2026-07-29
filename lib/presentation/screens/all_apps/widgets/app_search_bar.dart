import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/koru_type.dart';
import '../../../../core/theme/launcher_phase.dart';
import '../../../providers/app_list_provider.dart';

/// La riga di query del drawer — **in basso, sotto la lista, sopra la
/// tastiera**.
///
/// Non è più un box grigio Material in cima allo schermo: è una riga di
/// scrittura. Uno slash in accento, il testo digitato in serif grande, un
/// caret rettangolare, e a destra quante app restano. Il campo è dove il
/// pollice e la tastiera già sono, e i risultati crescono verso di lui invece
/// che allontanarsene.
class AppSearchBar extends ConsumerStatefulWidget {
  const AppSearchBar({
    required this.phase,
    required this.matchCount,
    super.key,
    this.autofocus = false,
  });

  final LauncherPhase phase;

  /// Quante app restano dopo il filtro. Arriva dal chiamante e non da un
  /// provider letto qui: questa è una riga di scrittura, non deve conoscere
  /// l'inventario delle app installate per disegnarsi.
  final int matchCount;

  /// Quando true il campo prende il focus all'apertura (apre la tastiera).
  /// Usato dall'azione swipe "Ricerca app" che apre il drawer già in ricerca.
  final bool autofocus;

  @override
  ConsumerState<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends ConsumerState<AppSearchBar> {
  final _controller = TextEditingController();

  /// PERF: debounce della query. Senza, ogni carattere scriveva
  /// `appSearchQueryProvider`, ricomputando `filteredAppsProvider` +
  /// `groupedAppsProvider` e riconciliando l'intera lista del drawer a ogni
  /// keystroke. Coalesciamo le digitazioni rapide in un solo aggiornamento.
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    // Rebuild quando cambia il testo così `CLR` compare e scompare: è valutato
    // in build() e senza questo listener non si aggiornerebbe alla digitazione
    // (AppSearchBar è costruita dal parent, che non ricostruisce questo State
    // a ogni keystroke).
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  /// Scrive la query nel provider DOPO il debounce, annullando il timer
  /// pendente a ogni nuovo carattere.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      ref.read(appSearchQueryProvider.notifier).state = value;
    });
  }

  /// Aggiornamento immediato (bypassa il debounce): usato da `CLR`, che non
  /// deve attendere né essere sovrascritto da un debounce pendente.
  void _setQueryNow(String value) {
    _debounce?.cancel();
    ref.read(appSearchQueryProvider.notifier).state = value;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sync esterno: se qualcuno (es. tap su una app, reset su resume) resetta
    // la query, svuota anche il TextField senza causare loop (controllo testo
    // attuale) e annulla un eventuale debounce pendente così la digitazione
    // precedente non riscrive la query appena resettata.
    ref.listen<String>(appSearchQueryProvider, (prev, next) {
      if (_controller.text != next) {
        _debounce?.cancel();
        _controller.text = next;
      }
    });

    final phase = widget.phase;
    final hasQuery = _controller.text.isNotEmpty;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: phase.hair)),
      ),
      child: Row(
        children: [
          Text(
            '/',
            style: KoruType.mono(size: 13, color: phase.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              cursorColor: phase.accent,
              cursorWidth: 2,
              cursorHeight: 28,
              // Il caret del design è un rettangolo netto, non la goccia
              // arrotondata di Material.
              cursorRadius: Radius.zero,
              style: KoruType.serif(size: 30, color: phase.ink),
              decoration: InputDecoration.collapsed(
                hintText: 'TYPE TO FILTER',
                hintStyle: KoruType.mono(
                  size: 11,
                  color: phase.ink2,
                  trackEm: phase.trackEm,
                ),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          if (hasQuery)
            // Una parola, non una "×": la tastiera di sistema non ha un tasto
            // "cancella tutto" e tenere premuto backspace è lento.
            GestureDetector(
              onTap: () {
                _controller.clear();
                _setQueryNow('');
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'CLR',
                  style: KoruType.mono(
                    size: 10,
                    color: phase.ink2,
                    trackEm: 0.1,
                  ),
                ),
              ),
            ),
          Text(
            '${widget.matchCount}'.padLeft(2, '0'),
            style: KoruType.mono(size: 11, color: phase.ink2, trackEm: 0.1),
          ),
        ],
      ),
    );
  }
}
