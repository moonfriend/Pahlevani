import 'dart:async';
import 'package:pahlevani/domain/services/player_notification_service.dart';

class FakePlayerNotificationService implements PlayerNotificationService {
  final _controller = StreamController<NotificationCommand>.broadcast();

  String? lastTitle;
  String? lastArtUri;
  bool? lastIsPlaying;
  Duration? lastDuration;

  @override
  void update({
    required String trackTitle,
    String? artUri,
    required bool isPlaying,
    Duration? duration,
  }) {
    lastTitle = trackTitle;
    lastArtUri = artUri;
    lastIsPlaying = isPlaying;
    lastDuration = duration;
  }

  @override
  Stream<NotificationCommand> get commands => _controller.stream;

  void emit(NotificationCommand cmd) => _controller.add(cmd);

  Future<void> dispose() => _controller.close();
}
