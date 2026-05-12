import 'package:flutter_test/flutter_test.dart';
import 'package:koru/platform/blocking_channel.dart';
import 'package:koru/platform/permission_channel.dart';
import 'package:koru/platform/platform_channel_service.dart';
import 'package:koru/platform/profile_channel.dart';
import 'package:koru/platform/service_event_channel.dart';
import 'package:koru/platform/strict_mode_channel.dart';

void main() {
  group('PlatformChannelService', () {
    test('constructor instantiates all 5 channel services', () {
      final service = PlatformChannelService();
      expect(service.blocking, isNotNull);
      expect(service.profile, isNotNull);
      expect(service.permission, isNotNull);
      expect(service.strictMode, isNotNull);
      expect(service.events, isNotNull);
    });

    test('channel fields have the expected runtime types', () {
      final service = PlatformChannelService();
      expect(service.blocking, isA<BlockingChannel>());
      expect(service.profile, isA<ProfileChannel>());
      expect(service.permission, isA<PermissionChannel>());
      expect(service.strictMode, isA<StrictModeChannel>());
      expect(service.events, isA<ServiceEventChannel>());
    });

    test('constructor can be called multiple times (not enforced singleton)',
        () {
      final a = PlatformChannelService();
      final b = PlatformChannelService();
      expect(identical(a, b), isFalse);
      expect(identical(a.blocking, b.blocking), isFalse);
      expect(identical(a.profile, b.profile), isFalse);
      expect(identical(a.permission, b.permission), isFalse);
      expect(identical(a.strictMode, b.strictMode), isFalse);
      expect(identical(a.events, b.events), isFalse);
    });
  });
}
