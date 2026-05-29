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

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sync esterno: se qualcuno (es. tap su una app) resetta la query,
    // svuota anche il TextField senza causare loop (controllo testo attuale).
    ref.listen<String>(appSearchQueryProvider, (prev, next) {
      if (_controller.text != next) _controller.text = next;
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
                    ref.read(appSearchQueryProvider.notifier).state = '';
                  },
                ),
          filled: true,
          fillColor: KoruColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) =>
            ref.read(appSearchQueryProvider.notifier).state = value,
      ),
    );
  }
}
