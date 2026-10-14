import 'package:equatable/equatable.dart';

/// What the locked screen says to someone without an activation code, and
/// where it sends them (our Patreon). Set in admin (migration 0045).
class LockedScreenText extends Equatable {
  const LockedScreenText(
      {required this.message, required this.linkLabel, required this.linkUrl});

  /// Shown before the first fetch and when offline with nothing cached.
  static const fallback = LockedScreenText(
    message: 'Pahlevani is for our Patreon members. Join on Patreon and '
        'you’ll get your activation code within a day.',
    linkLabel: 'Get your code on Patreon',
    linkUrl: 'https://www.patreon.com/',
  );

  final String message;
  final String linkLabel;
  final String linkUrl;

  @override
  List<Object?> get props => [message, linkLabel, linkUrl];
}
