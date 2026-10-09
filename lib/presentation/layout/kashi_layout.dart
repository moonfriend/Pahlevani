import 'package:flutter/widgets.dart';

/// The design's three layouts, picked by window width — never by platform,
/// so a narrow desktop window gets the phone layout and a wide tablet the
/// web one. The handoff's breakpoints: up to 600px phone, 600–1100px tablet
/// (3-column bento, 80px bottom bar), above 1100px web (232px side rail,
/// 4-column bento).
///
/// Use [of] for app-level decisions (navigation, page structure); inside a
/// component prefer the space it is given (`LayoutBuilder`), which also
/// holds next to the side rail.
enum KashiLayout {
  phone(bentoGap: 6, bentoRow: 104, bentoColumns: 2),
  tablet(bentoGap: 10, bentoRow: 176, bentoColumns: 3),
  web(bentoGap: 12, bentoRow: 180, bentoColumns: 4);

  const KashiLayout({
    required this.bentoGap,
    required this.bentoRow,
    required this.bentoColumns,
  });

  final double bentoGap;
  final double bentoRow;
  final int bentoColumns;

  static const tabletMinWidth = 600.0;
  static const webMinWidth = 1100.0;

  /// Width of the web layout's side rail.
  static const sideRailWidth = 232.0;

  static KashiLayout forWidth(double width) => width < tabletMinWidth
      ? phone
      : width <= webMinWidth
          ? tablet
          : web;

  /// The layout for the current window. Depends only on the window size,
  /// so it rebuilds on resize and nothing else.
  static KashiLayout of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  bool get isPhone => this == phone;
  bool get isWide => this == web;
}
