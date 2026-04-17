import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/di/providers.dart';
import '../../core/theme/font_catalog.dart';

/// Persisted font preference (integer KoruFont.id in Hive ui_state box).
class FontPreferenceNotifier extends Notifier<KoruFont> {
  @override
  KoruFont build() {
    final hive = ref.watch(hiveSettingsServiceProvider);
    final id = hive.getInt(HiveKeys.uiStateBox, HiveKeys.activeFontId);
    return KoruFont.fromId(id);
  }

  Future<void> set(KoruFont font) async {
    final hive = ref.read(hiveSettingsServiceProvider);
    await hive.put(HiveKeys.uiStateBox, HiveKeys.activeFontId, font.id);
    state = font;
  }
}

final fontPreferenceProvider =
    NotifierProvider<FontPreferenceNotifier, KoruFont>(FontPreferenceNotifier.new);
