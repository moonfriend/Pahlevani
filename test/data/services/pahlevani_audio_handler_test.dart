import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/pahlevani_audio_handler.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';

/// The OS media session (lock screen / notification) must only *forward*
/// intents to the player cubit — never drive the audio engine itself. When it
/// also played/paused the engine, the two disagreed: just_audio's play()
/// future completes only on the NEXT pause, so a lock-screen play reached the
/// cubit late, and the cubit's toggle then inverted the state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PahlevaniAudioHandler handler;
  late List<NotificationCommand> received;

  setUp(() {
    handler = PahlevaniAudioHandler();
    received = [];
    handler.commands.listen(received.add);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('lock-screen play is forwarded immediately as a play intent', () async {
    // Must not wait on the engine: with the old await-play, this never
    // completed until a later pause.
    await handler.play().timeout(const Duration(seconds: 1));
    await settle();
    expect(received, [NotificationCommand.play]);
  });

  test('lock-screen pause is forwarded as a pause intent', () async {
    await handler.pause().timeout(const Duration(seconds: 1));
    await settle();
    expect(received, [NotificationCommand.pause]);
  });

  test('lock-screen seek is forwarded with its position', () async {
    await handler
        .seek(const Duration(seconds: 12))
        .timeout(const Duration(seconds: 1));
    await settle();
    expect(received.single, isA<SeekCommand>());
    expect(
        (received.single as SeekCommand).position, const Duration(seconds: 12));
  });

  test('skip controls are forwarded', () async {
    await handler.skipToNext();
    await handler.skipToPrevious();
    await settle();
    expect(
        received, [NotificationCommand.skipNext, NotificationCommand.skipPrev]);
  });
}
