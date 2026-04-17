import 'dart:convert';

/// Sezioni in-app bloccabili. Enum values devono matchare con
/// [DetectedSection] lato native (Kotlin).
enum BlockedSection {
  instagramReels('INSTAGRAM_REELS', 'Instagram Reels', 'com.instagram.android'),
  instagramStories('INSTAGRAM_STORIES', 'Instagram Stories', 'com.instagram.android'),
  instagramExplore('INSTAGRAM_EXPLORE', 'Instagram Explore', 'com.instagram.android'),
  youtubeShorts('YOUTUBE_SHORTS', 'YouTube Shorts', 'com.google.android.youtube');

  const BlockedSection(this.wireId, this.displayName, this.packageName);

  final String wireId;
  final String displayName;
  final String packageName;

  static BlockedSection? fromWireId(String id) {
    for (final s in BlockedSection.values) {
      if (s.wireId == id) return s;
    }
    return null;
  }

  /// Set di sezioni serializzato come JSON `{"sections":["INSTAGRAM_REELS",...]}`.
  static String encodeSet(Set<BlockedSection> sections) => jsonEncode({
        'sections': sections.map((s) => s.wireId).toList(growable: false),
      });

  static Set<BlockedSection> decodeSet(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['sections'];
        if (list is List) {
          return list
              .map((e) => BlockedSection.fromWireId(e.toString()))
              .whereType<BlockedSection>()
              .toSet();
        }
      }
    } catch (_) {}
    return const {};
  }

  /// Sezioni supportate per un package specifico (UI discovery).
  static List<BlockedSection> forPackage(String packageName) =>
      BlockedSection.values.where((s) => s.packageName == packageName).toList(growable: false);

  /// Tutti i package supportati per in-app content blocking.
  static Set<String> supportedPackages =
      BlockedSection.values.map((s) => s.packageName).toSet();
}
