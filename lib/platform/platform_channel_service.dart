import 'blocking_channel.dart';
import 'permission_channel.dart';
import 'profile_channel.dart';
import 'service_event_channel.dart';
import 'strict_mode_channel.dart';

/// Facade singleton che raggruppa tutti i MethodChannel Koru in un unico punto.
/// Esposto tramite [platformChannelServiceProvider] in core/di/providers.dart.
class PlatformChannelService {
  PlatformChannelService()
      : blocking = BlockingChannel(),
        profile = ProfileChannel(),
        permission = PermissionChannel(),
        strictMode = StrictModeChannel(),
        events = ServiceEventChannel();

  final BlockingChannel blocking;
  final ProfileChannel profile;
  final PermissionChannel permission;
  final StrictModeChannel strictMode;
  final ServiceEventChannel events;
}
