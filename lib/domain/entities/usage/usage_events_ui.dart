part of 'usage_event.dart';

// ── D — friction signals (RQ2, RQ4, RQ5) ─────────────────────────────────

enum ErrorSurface { snackbar, dialog, inline }

/// An error or warning the user saw.
final class UiErrorShown extends UsageEvent {
  const UiErrorShown({required this.kind, required this.messageKey});

  final ErrorSurface kind;

  /// A short fixed key naming the message (e.g. `save_failed`), never the
  /// message's free text.
  final String messageKey;

  @override
  String get name => 'ui.error_shown';

  @override
  Map<String, Object?> get props =>
      {'kind': kind.wire, 'message_key': messageKey};
}

/// A tap that hit nothing that reacts to taps.
final class UiDeadTap extends UsageEvent {
  const UiDeadTap({
    required this.element,
    required this.cell,
    required this.xPct,
    required this.yPct,
    required this.disabledControl,
  });

  /// The TapProbe id of the look-alike that was tapped, if any.
  final String? element;

  /// Coarse 6×10 grid cell of the screen, e.g. `c3r7` (column 3, row 7).
  final String cell;
  final int xPct;
  final int yPct;

  /// The tap landed on a control that is switched off (a disabled button).
  final bool disabledControl;

  @override
  String get name => 'ui.dead_tap';

  @override
  Map<String, Object?> get props => {
        'element': element,
        'cell': cell,
        'x_pct': xPct,
        'y_pct': yPct,
        'disabled_control': disabledControl,
      };
}
