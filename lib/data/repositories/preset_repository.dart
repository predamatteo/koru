import 'dart:convert';

import 'package:flutter/services.dart';

import 'profile_repository.dart';

class KoruPreset {
  const KoruPreset({
    required this.presetId,
    required this.title,
    required this.emoji,
    required this.colorHex,
    required this.dayFlags,
    required this.blockingMode,
    required this.typeCombinations,
    required this.intervals,
    required this.blockedPackages,
  });

  final int presetId;
  final String title;
  final String emoji;
  final String colorHex;
  final int dayFlags;
  final int blockingMode;
  final int typeCombinations;
  final List<({int fromMinutes, int toMinutes})> intervals;
  final List<String> blockedPackages;

  factory KoruPreset.fromJson(Map<String, dynamic> json) => KoruPreset(
        presetId: json['presetId'] as int,
        title: json['title'] as String,
        emoji: json['emoji'] as String,
        colorHex: json['colorHex'] as String,
        dayFlags: json['dayFlags'] as int,
        blockingMode: json['blockingMode'] as int,
        typeCombinations: json['typeCombinations'] as int,
        intervals: (json['intervals'] as List)
            .map((e) => (
                  fromMinutes: (e as Map<String, dynamic>)['fromMinutes'] as int,
                  toMinutes: e['toMinutes'] as int,
                ))
            .toList(growable: false),
        blockedPackages: (json['blockedPackages'] as List).cast<String>(),
      );
}

class PresetRepository {
  PresetRepository(this._profileRepo);

  final ProfileRepository _profileRepo;

  static const _allAssetPaths = [
    'assets/presets/mindful_morning.json',
    'assets/presets/deep_work.json',
    'assets/presets/no_screen_evening.json',
  ];

  Future<List<KoruPreset>> loadAll() async {
    final presets = <KoruPreset>[];
    for (final path in _allAssetPaths) {
      final raw = await rootBundle.loadString(path);
      presets.add(KoruPreset.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return presets;
  }

  /// Crea il profilo dal preset e lo popola con intervals + blocked apps.
  /// Gli installed apps vengono filtrati: il native restituirà null per
  /// pacchetti non installati e il blocking engine semplicemente non li
  /// matcherà mai.
  Future<int> apply(KoruPreset preset) async {
    final id = await _profileRepo.createProfile(
      title: preset.title,
      emoji: preset.emoji,
      colorHex: preset.colorHex,
      dayFlags: preset.dayFlags,
      blockingMode: preset.blockingMode,
      typeCombinations: preset.typeCombinations,
      presetId: preset.presetId,
    );
    await _profileRepo.setIntervalsForProfile(
      id,
      preset.intervals
          .map((iv) => (from: iv.fromMinutes, to: iv.toMinutes))
          .toList(growable: false),
    );
    await _profileRepo.setAppsForProfile(id, preset.blockedPackages);
    return id;
  }
}
