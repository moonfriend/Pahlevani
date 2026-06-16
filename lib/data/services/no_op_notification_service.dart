import 'package:pahlevani/domain/services/player_notification_service.dart';

/// Used on Linux / Web where audio_service is not available.
/// All calls are no-ops; the command stream never emits.
class NoOpNotificationService implements PlayerNotificationService {
  @override
  void update({
    required String trackTitle,
    String? artUri,
    required bool isPlaying,
    Duration? duration,
  }) {}

  @override
  Stream<NotificationCommand> get commands => const Stream.empty();
}
