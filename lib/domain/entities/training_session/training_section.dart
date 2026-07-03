/// The seven Pahlevani disciplines that structure a training session,
/// plus a catch-all for uncategorised or future items.
///
/// DB column: `training_session_item.section` (text, nullable).
/// NULL in the DB is treated as [other] by [fromString].
enum TrainingSection {
  warmUp,
  sheno,
  mobility,
  meel,
  charkh,
  kabbade,
  sang,
  other;

  /// The string value stored in the DB CHECK constraint.
  String get value => switch (this) {
        warmUp => 'warm_up',
        sheno => 'sheno',
        mobility => 'mobility',
        meel => 'meel',
        charkh => 'charkh',
        kabbade => 'kabbade',
        sang => 'sang',
        other => 'other',
      };

  /// Persian display name shown in the trainer editor tabs.
  String get displayName => switch (this) {
        warmUp => 'گرم کردن',
        sheno => 'شنو',
        mobility => 'موبیلیتی',
        meel => 'میل',
        charkh => 'چرخ',
        kabbade => 'کباده',
        sang => 'سنگ',
        other => 'دیگر',
      };

  static TrainingSection fromString(String? s) => switch (s) {
        'warm_up' => warmUp,
        'sheno' => sheno,
        'mobility' => mobility,
        'meel' => meel,
        'charkh' => charkh,
        'kabbade' => kabbade,
        'sang' => sang,
        'other' => other,
        _ => other,
      };
}
