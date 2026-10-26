import 'dart:async';

import 'package:flutter/widgets.dart';

/// Counts down to [until] once a second, giving [builder] the seconds left,
/// or null once a new try is allowed (or when there is no pause).
///
/// Counts its own ticks after the first reading of the clock, so a frozen
/// test clock still ends the countdown.
class RetryCountdown extends StatefulWidget {
  const RetryCountdown({super.key, required this.until, required this.builder});

  final DateTime? until;
  final Widget Function(BuildContext context, int? secondsLeft) builder;

  @override
  State<RetryCountdown> createState() => _RetryCountdownState();
}

class _RetryCountdownState extends State<RetryCountdown> {
  Timer? _timer;
  int? _secondsLeft;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RetryCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) _start();
  }

  void _start() {
    _timer?.cancel();
    final until = widget.until;
    final millis =
        until == null ? 0 : until.difference(DateTime.now()).inMilliseconds;
    _secondsLeft = millis > 0 ? (millis / 1000).ceil() : null;
    if (_secondsLeft == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        final left = _secondsLeft! - 1;
        _secondsLeft = left > 0 ? left : null;
      });
      if (_secondsLeft == null) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _secondsLeft);
}
