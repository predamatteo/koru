import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/font_catalog.dart';
import '../../../providers/theme_provider.dart';

class FontScreen extends ConsumerWidget {
  const FontScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(fontPreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Font')),
      body: RadioGroup<KoruFont>(
        groupValue: current,
        onChanged: (f) {
          if (f != null) ref.read(fontPreferenceProvider.notifier).set(f);
        },
        child: ListView(
          children: [
            for (final font in KoruFont.values)
              RadioListTile<KoruFont>(
                value: font,
                title: Text(
                  font.displayName,
                  style: TextStyle(fontFamily: font.family),
                ),
                subtitle: Text(
                  'The quick brown fox jumps over the lazy dog',
                  style: TextStyle(fontFamily: font.family),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
