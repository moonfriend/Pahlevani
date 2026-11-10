part of 'usage_event.dart';

// ── B — screens and navigation (RQ3, RQ4) ────────────────────────────────

/// How the user got to a screen.
enum NavVia { tab, button, back, gate, system }

enum BackKind { system, appBar, swipe }

/// How a dialog or sheet closed: with a positive answer, a negative one, or
/// by tapping outside / Back (no answer).
enum PopupResult { confirmed, cancelled, dismissed }

/// Every external link the app opens.
enum ExternalLink {
  meelGuide,
  activationInfo,
  terms,
  privacy,
  announcement,
  onboarding,
  store,
}

final class NavScreenViewed extends UsageEvent {
  const NavScreenViewed(
      {required this.screen, required this.previous, required this.via});

  final String screen;

  /// Null for the first screen of a visit.
  final String? previous;
  final NavVia via;

  @override
  String get name => 'nav.screen_viewed';

  @override
  Map<String, Object?> get props =>
      {'screen': screen, 'previous': previous, 'via': via.wire};
}

final class NavScreenLeft extends UsageEvent {
  const NavScreenLeft(
      {required this.screen, required this.seconds, this.scrollDepthPct});

  final String screen;
  final double seconds;

  /// How far down the screen was scrolled at most (0–100); null when the
  /// screen didn't scroll.
  final int? scrollDepthPct;

  @override
  String get name => 'nav.screen_left';

  @override
  Map<String, Object?> get props => {
        'screen': screen,
        'seconds': _s(seconds),
        'scroll_depth_pct': scrollDepthPct,
      };
}

final class NavTabSelected extends UsageEvent {
  const NavTabSelected(
      {required this.from, required this.to, required this.reselected});

  final String from;
  final String to;

  /// The current tab tapped again.
  final bool reselected;

  @override
  String get name => 'nav.tab_selected';

  @override
  Map<String, Object?> get props =>
      {'from': from, 'to': to, 'reselected': reselected};
}

final class NavBack extends UsageEvent {
  const NavBack({required this.kind, required this.from});

  final BackKind kind;
  final String from;

  @override
  String get name => 'nav.back';

  @override
  Map<String, Object?> get props => {'kind': kind.wire, 'from': from};
}

final class NavDialogShown extends UsageEvent {
  const NavDialogShown({required this.dialog});

  final String dialog;

  @override
  String get name => 'nav.dialog_shown';

  @override
  Map<String, Object?> get props => {'dialog': dialog};
}

final class NavDialogClosed extends UsageEvent {
  const NavDialogClosed(
      {required this.dialog, required this.result, required this.seconds});

  final String dialog;
  final PopupResult result;
  final double seconds;

  @override
  String get name => 'nav.dialog_closed';

  @override
  Map<String, Object?> get props =>
      {'dialog': dialog, 'result': result.wire, 'seconds': _s(seconds)};
}

final class NavSheetShown extends UsageEvent {
  const NavSheetShown({required this.sheet});

  final String sheet;

  @override
  String get name => 'nav.sheet_shown';

  @override
  Map<String, Object?> get props => {'sheet': sheet};
}

final class NavSheetClosed extends UsageEvent {
  const NavSheetClosed(
      {required this.sheet, required this.result, required this.seconds});

  final String sheet;
  final PopupResult result;
  final double seconds;

  @override
  String get name => 'nav.sheet_closed';

  @override
  Map<String, Object?> get props =>
      {'sheet': sheet, 'result': result.wire, 'seconds': _s(seconds)};
}

final class NavLinkOpened extends UsageEvent {
  const NavLinkOpened({required this.link, required this.urlHost});

  final ExternalLink link;

  /// Only the host — the links are ours or admin-set, the path adds nothing.
  final String urlHost;

  @override
  String get name => 'nav.link_opened';

  @override
  Map<String, Object?> get props => {'link': link.wire, 'url_host': urlHost};
}
