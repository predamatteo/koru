import 'package:flutter_test/flutter_test.dart';
import 'package:koru/domain/entities/blocked_section.dart';

void main() {
  group('BlockedSection', () {
    test('wireIds matching native DetectedSection', () {
      expect(BlockedSection.instagramReels.wireId, 'INSTAGRAM_REELS');
      expect(BlockedSection.instagramStories.wireId, 'INSTAGRAM_STORIES');
      expect(BlockedSection.instagramExplore.wireId, 'INSTAGRAM_EXPLORE');
      expect(BlockedSection.youtubeShorts.wireId, 'YOUTUBE_SHORTS');
    });

    test('encode/decode roundtrip', () {
      final original = {
        BlockedSection.instagramReels,
        BlockedSection.youtubeShorts,
      };
      final encoded = BlockedSection.encodeSet(original);
      final decoded = BlockedSection.decodeSet(encoded);
      expect(decoded, original);
    });

    test('decodeSet handles null and malformed input', () {
      expect(BlockedSection.decodeSet(null), isEmpty);
      expect(BlockedSection.decodeSet(''), isEmpty);
      expect(BlockedSection.decodeSet('{invalid json'), isEmpty);
      expect(BlockedSection.decodeSet('{"sections":["BOGUS"]}'), isEmpty);
    });

    test('forPackage filters to sections of a given app', () {
      final igSections = BlockedSection.forPackage('com.instagram.android');
      expect(igSections.length, 3);
      expect(igSections, contains(BlockedSection.instagramReels));

      final ytSections = BlockedSection.forPackage('com.google.android.youtube');
      expect(ytSections, [BlockedSection.youtubeShorts]);
    });
  });
}
