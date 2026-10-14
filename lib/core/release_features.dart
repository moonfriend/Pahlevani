/// Features built but switched off for release 1 (the curated first
/// product, 2026-10-14). Each switch is the one place its feature is hidden;
/// flip it back to `true` to bring the feature back. See
/// `docs/hidden_features.md` for what else each feature needs.
abstract final class ReleaseFeatures {
  /// The Progress tab (shamseh, calendar, counted moves).
  static const progressTab = false;

  /// "Only follow along" (Athlete mode) beside Start in the session preview.
  static const followAlongButton = false;

  /// The Rep log after each counted move. Release 1 logs no reps; the first
  /// update brings Shena/Meel totals on the Complete screen instead.
  static const repLogging = false;
}
