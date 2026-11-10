/// The look-alike elements tagged with a TapProbe: things that look
/// tappable but do nothing (reviewed list, 2026-11-06). A tap on one is
/// logged as `ui.dead_tap` with its id.
abstract final class TapProbeIds {
  static const splashLogo = 'splash.logo';
  static const onboardingCardImage = 'onboarding.card_image';
  static const onboardingCardTitle = 'onboarding.card_title';
  static const homeGreeting = 'home.greeting';
  static const libraryTitle = 'library.title';
  static const librarySectionLabel = 'library.section_label';
  static const previewSessionStill = 'preview.session_still';
  static const previewSessionTitle = 'preview.session_title';
  static const previewSessionMeta = 'preview.session_meta';
  static const previewReviewText = 'preview.review_text';
  static const previewMovesLabel = 'preview.moves_label';
  static const previewWarmupNote = 'preview.warmup_note';
  static const learningCardTitle = 'learning_card.title';
  static const learningCardReps = 'learning_card.reps';
  static const learningCardCues = 'learning_card.cues';
  static const learningCardComingSoon = 'learning_card.coming_soon';
  static const playerRepCounter = 'player.rep_counter';
  static const playerCues = 'player.cues';
  static const completeRepCard = 'complete.rep_card';
  static const completeTitle = 'complete.title';
  static const profileAvatar = 'profile.avatar';
  static const profileName = 'profile.name';
  static const profileCountedNote = 'profile.counted_note';
  static const lockedText = 'locked.text';
  static const consentText = 'consent.text';

  static const all = [
    splashLogo,
    onboardingCardImage,
    onboardingCardTitle,
    homeGreeting,
    libraryTitle,
    librarySectionLabel,
    previewSessionStill,
    previewSessionTitle,
    previewSessionMeta,
    previewReviewText,
    previewMovesLabel,
    previewWarmupNote,
    learningCardTitle,
    learningCardReps,
    learningCardCues,
    learningCardComingSoon,
    playerRepCounter,
    playerCues,
    completeRepCard,
    completeTitle,
    profileAvatar,
    profileName,
    profileCountedNote,
    lockedText,
    consentText,
  ];

  /// `player.rep_counter` → `playerRepCounter`.
  static String constantName(String id) {
    final words = id.split(RegExp('[._]'));
    return words.first +
        [for (final w in words.skip(1)) w[0].toUpperCase() + w.substring(1)]
            .join();
  }
}
