/// Commands fired by the OS media session (lock screen / notification card).
///
/// Each one is an explicit intent — play means play, pause means pause —
/// never a toggle, so a command can't invert the player's state when the OS
/// and the app briefly disagree about it. Seek carries its target position on
/// the move's timeline (the same timeline the in-app seek bar uses).
sealed class NotificationCommand {
  const NotificationCommand();

  static const play = PlayCommand();
  static const pause = PauseCommand();
  static const skipNext = SkipNextCommand();
  static const skipPrev = SkipPrevCommand();
  const factory NotificationCommand.seek(Duration position) = SeekCommand;
}

final class PlayCommand extends NotificationCommand {
  const PlayCommand();
}

final class PauseCommand extends NotificationCommand {
  const PauseCommand();
}

final class SkipNextCommand extends NotificationCommand {
  const SkipNextCommand();
}

final class SkipPrevCommand extends NotificationCommand {
  const SkipPrevCommand();
}

final class SeekCommand extends NotificationCommand {
  const SeekCommand(this.position);
  final Duration position;
}

/// Bridge between the OS media session and the player cubit.
///
/// - [update] is called by the cubit to set what title / art the notification
///   shows and whether the play or pause icon is shown.
/// - [commands] emits when the user uses a lock-screen / notification
///   control; the cubit is the only thing that acts on it (the media session
///   itself never drives the audio engine), so app and OS can't diverge.
abstract class PlayerNotificationService {
  void update({
    required String trackTitle,
    String? artUri,
    required bool isPlaying,
    Duration? duration,
  });

  Stream<NotificationCommand> get commands;
}
