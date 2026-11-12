import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/usage/usage_event.dart';
import '../../../domain/services/usage_tracker.dart';

/// Profile's "Share usage data" switch: whether the study logs this user.
class UsageSharingCubit extends Cubit<bool> {
  UsageSharingCubit(this._tracker) : super(_tracker.enabled);

  final UsageTracker _tracker;

  /// Turning off is logged — and sent, if possible — before tracking stops,
  /// so the study sees when someone opted out. Turning on is logged after.
  Future<void> set(bool on) async {
    if (on == state) return;
    emit(on);
    if (on) {
      await _tracker.setEnabled(true);
      _tracker.track(const ProfileTrackingToggled(on: true));
    } else {
      _tracker.track(const ProfileTrackingToggled(on: false));
      await _tracker.flush();
      await _tracker.setEnabled(false);
    }
  }
}
