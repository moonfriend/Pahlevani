import 'package:equatable/equatable.dart';

/// What the locked screen says to someone without an activation code, and
/// where it sends them (our Steady page). Set in admin (migration 0045).
class LockedScreenText extends Equatable {
  const LockedScreenText(
      {required this.message, required this.linkLabel, required this.linkUrl});

  /// Shown before the first fetch and when offline with nothing cached.
  static const fallback = LockedScreenText(
    message: 'Gowd app is available to our early supporters. Join on Steady '
        'and you’ll get your activation code immediately.',
    linkLabel: 'Join on Steady',
    linkUrl: 'https://steady.page/en/join-the-gowd',
  );

  final String message;
  final String linkLabel;
  final String linkUrl;

  @override
  List<Object?> get props => [message, linkLabel, linkUrl];
}
