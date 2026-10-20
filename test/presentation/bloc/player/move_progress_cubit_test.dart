import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/presentation/bloc/player/move_progress_cubit.dart';

import '../../../fakes/fake_audio_player_service.dart';

Duration ms(int v) => Duration(milliseconds: v);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late FakeAudioPlayerService engine;
  late MoveTimeline timeline;

  setUp(() {
    engine = FakeAudioPlayerService();
    timeline = MoveTimeline(engine);
  });

  tearDown(() => timeline.close());

  const move = MoveSpec(audioPath: '/a', clipReps: 10, targetReps: 10);

  test('starts from where the move already is (joining mid-move)', () async {
    await timeline.load(move, play: true);
    engine.emitDuration(ms(10000));
    await settle();
    engine.emitPosition(ms(3200));
    await settle();

    final cubit = MoveProgressCubit(timeline);
    addTearDown(cubit.close);

    expect(cubit.state.position, ms(3200));
    expect(cubit.state.rep, 4);
  });

  test('follows the move as it plays', () async {
    final cubit = MoveProgressCubit(timeline);
    addTearDown(cubit.close);
    await timeline.load(move, play: true);
    engine.emitDuration(ms(10000));
    await settle();
    engine.emitPosition(ms(7500));
    await settle();

    expect(cubit.state.position, ms(7500));
    expect(cubit.state.length, ms(10000));
  });

  test('stops following once closed', () async {
    final cubit = MoveProgressCubit(timeline);
    await cubit.close();
    await timeline.load(move, play: true);
    engine.emitDuration(ms(10000));
    await settle();

    expect(cubit.state, MoveProgress.none);
  });
}
