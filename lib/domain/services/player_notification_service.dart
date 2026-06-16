/// Commands fired by the OS notification card (lock screen / dropdown controls).
/// The cubit subscribes to [commands] and translates them into player actions.
enum NotificationCommand { play, pause, skipNext, skipPrev }

/// Bridge between the OS media session and the player cubit.
///
/// - [update] is called by the cubit to set what title / art the notification
///   shows and whether the play or pause icon is shown.
/// - [commands] emits when the user taps a notification button; the cubit
///   reacts by calling [next], [prev], or [togglePlay].
abstract class PlayerNotificationService {
  void update({
    required String trackTitle,
    String? artUri,
    required bool isPlaying,
    Duration? duration,
  });

  Stream<NotificationCommand> get commands;
}
