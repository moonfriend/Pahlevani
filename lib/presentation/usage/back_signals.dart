import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:flutter/widgets.dart';

import '../../domain/entities/usage/usage_event.dart';
import 'usage_scope.dart';

/// Remembers how the user just asked to go back, until the pop it causes.
///
/// The pop itself (seen by the navigator observer) looks the same whatever
/// caused it; this tells a system Back, a swipe and the app's own back
/// arrow apart. A signal older than [window] is stale — it belonged to a
/// Back that didn't pop anything.
class BackSignals {
  BackSignals(
      {DateTime Function()? now, this.window = const Duration(seconds: 1)})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration window;
  BackKind? _kind;
  DateTime? _at;

  void system() => _set(BackKind.system);
  void swipe() => _set(BackKind.swipe);
  void appBar() => _set(BackKind.appBar);

  /// The pending signal, if fresh; it is used up either way.
  BackKind? consume() {
    final kind = _kind, at = _at;
    _kind = null;
    _at = null;
    if (kind == null || at == null || _now().difference(at) > window) {
      return null;
    }
    return kind;
  }

  void _set(BackKind kind) {
    _kind = kind;
    _at = _now();
  }
}

/// Hears the system Back (button, gesture, predictive back) before the app
/// handles it, and never handles it itself.
///
/// Flutter asks binding observers in registration order and stops at the
/// first that handles Back — the app's own navigator observer, registered
/// when the app starts. So this probe must be added in `main()` before
/// `runApp`.
class SystemBackProbe with WidgetsBindingObserver {
  SystemBackProbe(this._signals);

  final BackSignals _signals;

  @override
  Future<bool> didPopRoute() async {
    _signals.system();
    return false;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    _signals.system();
    return false;
  }
}

/// The app's own back arrows: pops like the AppBar's back button, and
/// tells the study it was the in-app arrow.
void popWithAppBarBack(BuildContext context) {
  context.screens?.back.appBar();
  Navigator.maybePop(context);
}
