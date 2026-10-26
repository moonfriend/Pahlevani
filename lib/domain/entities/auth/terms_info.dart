import 'package:equatable/equatable.dart';

import 'consent.dart';

/// The terms and privacy policy version users must have agreed to, and when
/// it was published. Set in admin after the website's texts change
/// (migration 0049); raising [version] asks everyone to agree again.
class TermsInfo extends Equatable {
  const TermsInfo({required this.version, this.updatedOn});

  /// The app's own value: used offline before the server was ever reached.
  static final fallback =
      TermsInfo(version: currentTermsVersion, updatedOn: currentTermsUpdatedOn);

  final int version;
  final DateTime? updatedOn;

  @override
  List<Object?> get props => [version, updatedOn];
}
