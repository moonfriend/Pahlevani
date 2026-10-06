import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';

/// The current move's progress — position, length, rep — for the few widgets
/// that show it (rep counter, progress bar).
///
/// Kept apart from the session's player state on purpose: progress changes
/// many times a second, the session (which move, playing or not) rarely, and
/// mixing them made the whole player page rebuild at audio speed.
class MoveProgressCubit extends Cubit<MoveProgress> {
  late final StreamSubscription<MoveProgress> _sub;

  /// Starts from [timeline]'s current progress, so a cubit created mid-move
  /// is right immediately rather than after the next reading.
  MoveProgressCubit(MoveTimeline timeline) : super(timeline.current) {
    _sub = timeline.progress.listen(emit);
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
