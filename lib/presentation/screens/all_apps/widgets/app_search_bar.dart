import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/koru_colors.dart';
import '../../../providers/app_list_provider.dart';

class AppSearchBar extends ConsumerStatefulWidget {
  const AppSearchBar({super.key, this.autofocus = false});

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
    // Rebuild quando cambia il testo così il pulsante "clear" (X) compare e
    // scompare: il suffixIcon è valutato in build() e senza questo listener
    // non si aggiornerebbe alla digitazione (AppSearchBar è `const` nel
    // parent, che quindi non ricostruisce questo State a ogni keystroke).
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

  /// Aggiornamento immediato (bypassa il debounce): usato dal pulsante clear,
  /// che non deve attendere né essere sovrascritto da un debounce pendente.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          hintText: 'Search apps',
          prefixIcon: const Icon(Icons.search, color: KoruColors.textSecondary),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: KoruColors.textSecondary,
                  ),
                  onPressed: () {
                    _controller.clear();
                    _setQueryNow('');
                  },
                ),
          filled: true,
          fillColor: KoruColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onQueryChanged,
      ),
    );
  }
}
