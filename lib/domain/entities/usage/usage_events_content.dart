part of 'usage_event.dart';

// ── C — first open, Home, Library, learning card, Profile (RQ3, RQ4) ─────

enum OnboardingVia { swipe, button }

enum HomeCardTarget { card, startButton }

enum TodayPageVia { swipe, dot }

/// Where a learning card was opened from.
enum CardSource { library, preview, player }

enum CardVideo { learning, followAlong }

enum ProfileEntry {
  languageFa,
  appearance,
  morshed,
  signOut,
  deleteAccount,
  trainerTools,
  shareUsage,
}

enum MorshedSource { profile, preview }

final class SplashBeginTapped extends UsageEvent {
  const SplashBeginTapped({required this.seconds});

  /// Time on the splash before Begin.
  final double seconds;

  @override
  String get name => 'splash.begin_tapped';

  @override
  Map<String, Object?> get props => {'seconds': _s(seconds)};
}

final class OnboardingCardViewed extends UsageEvent {
  const OnboardingCardViewed({
    required this.index,
    required this.of,
    required this.previousCardSeconds,
    required this.via,
  });

  final int index;
  final int of;

  /// Time spent on the card before this one.
  final double previousCardSeconds;
  final OnboardingVia via;

  @override
  String get name => 'onboarding.card_viewed';

  @override
  Map<String, Object?> get props => {
        'index': index,
        'of': of,
        'previous_card_s': _s(previousCardSeconds),
        'via': via.wire,
      };
}

final class OnboardingFinished extends UsageEvent {
  const OnboardingFinished({required this.atCard, required this.seconds});

  final int atCard;
  final double seconds;

  @override
  String get name => 'onboarding.finished';

  @override
  Map<String, Object?> get props => {'at_card': atCard, 'seconds': _s(seconds)};
}

final class OnboardingSkipped extends UsageEvent {
  const OnboardingSkipped({required this.atCard, required this.seconds});

  final int atCard;
  final double seconds;

  @override
  String get name => 'onboarding.skipped';

  @override
  Map<String, Object?> get props => {'at_card': atCard, 'seconds': _s(seconds)};
}

final class HomeSessionCardTapped extends UsageEvent {
  const HomeSessionCardTapped(
      {required this.slot, required this.sessionId, required this.target});

  /// 0 = the big Today card, then the small cards in order.
  final int slot;
  final int sessionId;
  final HomeCardTarget target;

  @override
  String get name => 'home.session_card_tapped';

  @override
  Map<String, Object?> get props =>
      {'slot': slot, 'session_id': sessionId, 'target': target.wire};
}

final class HomeSessionMenuOpened extends UsageEvent {
  const HomeSessionMenuOpened({required this.sessionId});

  final int sessionId;

  @override
  String get name => 'home.session_menu_opened';

  @override
  Map<String, Object?> get props => {'session_id': sessionId};
}

final class HomeAnnouncementTapped extends UsageEvent {
  const HomeAnnouncementTapped();

  @override
  String get name => 'home.announcement_tapped';

  @override
  Map<String, Object?> get props => const {};
}

final class HomeTodayPageChanged extends UsageEvent {
  const HomeTodayPageChanged({required this.index, required this.via});

  final int index;
  final TodayPageVia via;

  @override
  String get name => 'home.today_page_changed';

  @override
  Map<String, Object?> get props => {'index': index, 'via': via.wire};
}

final class LibraryMoveOpened extends UsageEvent {
  const LibraryMoveOpened({required this.movementId, required this.position});

  final int movementId;
  final int position;

  @override
  String get name => 'library.move_opened';

  @override
  Map<String, Object?> get props =>
      {'movement_id': movementId, 'position': position};
}

final class LibrarySessionOpened extends UsageEvent {
  const LibrarySessionOpened({required this.sessionId, required this.position});

  final int sessionId;
  final int position;

  @override
  String get name => 'library.session_opened';

  @override
  Map<String, Object?> get props =>
      {'session_id': sessionId, 'position': position};
}

final class LearningCardOpened extends UsageEvent {
  const LearningCardOpened({required this.movementId, required this.from});

  final int movementId;
  final CardSource from;

  @override
  String get name => 'learning_card.opened';

  @override
  Map<String, Object?> get props =>
      {'movement_id': movementId, 'from': from.wire};
}

final class LearningCardVideoPlayed extends UsageEvent {
  const LearningCardVideoPlayed(
      {required this.movementId, required this.video});

  final int movementId;
  final CardVideo video;

  @override
  String get name => 'learning_card.video_played';

  @override
  Map<String, Object?> get props =>
      {'movement_id': movementId, 'video': video.wire};
}

final class LearningCardVideoClosed extends UsageEvent {
  const LearningCardVideoClosed(
      {required this.movementId,
      required this.video,
      required this.watchedPct});

  final int movementId;
  final CardVideo video;

  /// Furthest point reached, 0–100.
  final int watchedPct;

  @override
  String get name => 'learning_card.video_closed';

  @override
  Map<String, Object?> get props => {
        'movement_id': movementId,
        'video': video.wire,
        'watched_pct': watchedPct,
      };
}

final class LearningCardVideoToggled extends UsageEvent {
  const LearningCardVideoToggled({required this.to});

  final CardVideo to;

  @override
  String get name => 'learning_card.video_toggled';

  @override
  Map<String, Object?> get props => {'to': to.wire};
}

final class LearningCardFullscreen extends UsageEvent {
  const LearningCardFullscreen({required this.on});

  final bool on;

  @override
  String get name => 'learning_card.fullscreen';

  @override
  Map<String, Object?> get props => {'on': on};
}

final class LearningCardAction extends UsageEvent {
  const LearningCardAction({required this.movementId, required this.action});

  final int movementId;

  /// The card's action button label (a fixed app string, e.g. "Go").
  final String action;

  @override
  String get name => 'learning_card.action';

  @override
  Map<String, Object?> get props =>
      {'movement_id': movementId, 'action': action};
}

final class LearningCardLearntToggled extends UsageEvent {
  const LearningCardLearntToggled(
      {required this.movementId, required this.learnt});

  final int movementId;
  final bool learnt;

  @override
  String get name => 'learning_card.learnt_toggled';

  @override
  Map<String, Object?> get props =>
      {'movement_id': movementId, 'learnt': learnt};
}

final class ProfileEntryTapped extends UsageEvent {
  const ProfileEntryTapped({required this.entry});

  final ProfileEntry entry;

  @override
  String get name => 'profile.entry_tapped';

  @override
  Map<String, Object?> get props => {'entry': entry.wire};
}

/// The "Share usage data" switch. Turning it off is the last event sent.
final class ProfileTrackingToggled extends UsageEvent {
  const ProfileTrackingToggled({required this.on});

  final bool on;

  @override
  String get name => 'profile.tracking_toggled';

  @override
  Map<String, Object?> get props => {'on': on};
}

final class SettingsThemeChanged extends UsageEvent {
  const SettingsThemeChanged({required this.mode});

  /// `system`, `light` or `dark`.
  final String mode;

  @override
  String get name => 'settings.theme_changed';

  @override
  Map<String, Object?> get props => {'mode': mode};
}

final class MorshedChosen extends UsageEvent {
  const MorshedChosen({required this.morshedId, required this.from});

  final int morshedId;
  final MorshedSource from;

  @override
  String get name => 'morshed.chosen';

  @override
  Map<String, Object?> get props =>
      {'morshed_id': morshedId, 'from': from.wire};
}
