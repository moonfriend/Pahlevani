import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';

/// One instance of every event in the catalogue.
final List<UsageEvent> samples = [
  // A — visits
  const AppFirstOpen(),
  const AppOpened(
    start: AppStart.cold,
    sinceLastVisitSeconds: 3600,
    deviceClass: DeviceClass.phone,
    os: 'android',
    osVersion: '14',
    locale: 'en_US',
    network: NetworkKind.wifi,
  ),
  const AppBackgrounded(visitSeconds: 42),
  const AppForegrounded(awaySeconds: 12, newVisit: false),
  // B — navigation
  const NavScreenViewed(screen: 'home', previous: 'splash', via: NavVia.gate),
  const NavScreenLeft(screen: 'home', seconds: 3.5, scrollDepthPct: 40),
  const NavTabSelected(from: 'home', to: 'library', reselected: false),
  const NavBack(kind: BackKind.system, from: 'preview'),
  const NavDialogShown(dialog: 'zoorkhaneh_confirm'),
  const NavDialogClosed(
      dialog: 'zoorkhaneh_confirm', result: PopupResult.confirmed, seconds: 2),
  const NavSheetShown(sheet: 'session_menu'),
  const NavSheetClosed(
      sheet: 'session_menu', result: PopupResult.dismissed, seconds: 1),
  const NavLinkOpened(link: ExternalLink.meelGuide, urlHost: 'rahaavi.com'),
  // C — auth & access
  const AuthScreenMode(mode: AuthMode.signIn),
  const AuthSubmit(
      mode: AuthMode.createAccount,
      secondsOnScreen: 30,
      corrections: 2,
      attempt: 1),
  const AuthResult(
      mode: AuthMode.signIn,
      ok: false,
      error: AuthErrorKind.wrongCredentials,
      seconds: 1.2),
  const AuthConsentShown(isUpdate: false),
  const AuthConsentAccepted(
      seconds: 9, openedTerms: true, openedPrivacy: false),
  const AuthConsentDeclined(seconds: 4),
  const AuthSignedOut(),
  const AuthAccountDeleted(),
  const AccessCodeEntered(result: CodeResult.invalid, attempt: 2),
  const AccessLockedScreenAction(action: LockedAction.link),
  // C — onboarding
  const SplashBeginTapped(seconds: 4),
  const OnboardingCardViewed(
      index: 1, of: 4, previousCardSeconds: 3, via: OnboardingVia.swipe),
  const OnboardingFinished(atCard: 3, seconds: 20),
  const OnboardingSkipped(atCard: 0, seconds: 2),
  // C — home, library, profile, learning card
  const HomeSessionCardTapped(
      slot: 0, sessionId: 7, target: HomeCardTarget.startButton),
  const HomeSessionMenuOpened(sessionId: 7),
  const HomeAnnouncementTapped(),
  const HomeTodayPageChanged(index: 1, via: TodayPageVia.swipe),
  const LibraryMoveOpened(movementId: 3, position: 2),
  const LibrarySessionOpened(sessionId: 7, position: 0),
  const LearningCardOpened(movementId: 3, from: CardSource.library),
  const LearningCardVideoPlayed(movementId: 3, video: CardVideo.learning),
  const LearningCardVideoClosed(
      movementId: 3, video: CardVideo.followAlong, watchedPct: 80),
  const LearningCardVideoToggled(to: CardVideo.followAlong),
  const LearningCardFullscreen(on: true),
  const LearningCardAction(movementId: 3, action: 'Go'),
  const LearningCardLearntToggled(movementId: 3, learnt: true),
  const ProfileEntryTapped(entry: ProfileEntry.languageFa),
  const ProfileTrackingToggled(on: false),
  const SettingsThemeChanged(mode: 'dark'),
  const MorshedChosen(morshedId: 2, from: MorshedSource.preview),
  // C — session & player
  const SessionPreviewed(sessionId: 7, source: PreviewSource.home, moves: 12),
  const PreviewMoveOpened(sessionId: 7, movementId: 3, position: 2),
  const PreviewModeTapped(sessionId: 7, mode: UsageSessionMode.athlete),
  const PreviewLeft(
      sessionId: 7, how: PreviewExit.back, seconds: 14, movesOpened: 2),
  const SessionStarted(
      sessionId: 7,
      mode: UsageSessionMode.learning,
      morshedId: 2,
      downloaded: true,
      moves: 12),
  const SessionCompleted(
      sessionId: 7,
      seconds: 1500,
      playedSeconds: 1300,
      pauses: 3,
      replays: 0,
      seeks: 2),
  const SessionAbandoned(
      sessionId: 7, lastIndex: 4, playedSeconds: 300, how: AbandonHow.killed),
  const DownloadStarted(
      target: DownloadTargetKind.session, id: 7, tier: 'audio', bytes: 1000),
  const DownloadFinished(
      target: DownloadTargetKind.session,
      id: 7,
      tier: 'audio',
      bytes: 1000,
      seconds: 20),
  const DownloadFailed(
      target: DownloadTargetKind.session,
      id: 7,
      tier: 'audio',
      error: DownloadErrorKind.network),
  const DownloadDeclined(target: DownloadTargetKind.session, id: 7),
  const PlayerMoveReached(index: 2, movementId: 3, waitingForGo: true),
  const PlayerGoTapped(index: 2, waitedSeconds: 8),
  const PlayerPaused(
      index: 2, positionSeconds: 10.5, source: CommandSource.screen),
  const PlayerResumed(
      index: 2, positionSeconds: 10.5, source: CommandSource.mediaSession),
  const PlayerNext(
      from: 2, to: 3, positionSeconds: 4, source: CommandSource.screen),
  const PlayerPrev(
      from: 3, to: 2, positionSeconds: 1, source: CommandSource.screen),
  const PlayerReplay(fromIndex: 11),
  const PlayerSeek(
      index: 2, fromSeconds: 20, toSeconds: 5, source: CommandSource.screen),
  const PlayerMuted(on: true),
  const PlayerMoveListJump(from: 2, to: 7),
  const PlayerHowToOpened(index: 2, movementId: 3),
  const PlayerFullscreen(on: true),
  const PlayerProgressToggled(visible: false),
  const PlayerMoveEnded(
    index: 2,
    movementId: 3,
    playedSeconds: 12.4,
    plannedSeconds: 30,
    reachedPct: 41,
    repsReached: 5,
    repsPlanned: 12,
    pauses: 1,
    seeks: 0,
    how: MoveEndReason.next,
  ),
  const PlayerRepLogged(index: 2, reps: 10, target: 12),
  const PlayerRepLogSkipped(index: 2, target: 12),
  const CompleteActionTaken(action: CompleteAction.returnHome, seconds: 6),
  // D — friction
  const UiErrorShown(kind: ErrorSurface.snackbar, messageKey: 'save_failed'),
  const UiDeadTap(
      element: 'player.rep_counter',
      cell: 'c3r7',
      xPct: 52,
      yPct: 71,
      disabledControl: false),
];

final _namePattern = RegExp(r'^[a-z_]+\.[a-z_]+$');

/// The event names listed in the catalogue doc's tables.
Set<String> _documentedNames() {
  final doc = File('docs/usage_study/event_catalogue.md').readAsStringSync();
  return RegExp(r'^\| `([a-z_]+\.[a-z_]+)`', multiLine: true)
      .allMatches(doc)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  test('every event name has the area.action shape', () {
    for (final e in samples) {
      expect(e.name, matches(_namePattern), reason: '${e.runtimeType}');
    }
  });

  test('event names are unique', () {
    final names = samples.map((e) => e.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('one sample per event class', () {
    final types = samples.map((e) => e.runtimeType).toList();
    expect(types.toSet().length, types.length);
  });

  test('props survive a JSON round trip with snake_case keys', () {
    for (final e in samples) {
      final decoded = jsonDecode(jsonEncode(e.props)) as Map<String, dynamic>;
      expect(decoded, e.props, reason: e.name);
      for (final key in e.props.keys) {
        expect(key, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: e.name);
      }
    }
  });

  test('enum values go out in snake_case', () {
    expect(
        const NavLinkOpened(link: ExternalLink.meelGuide, urlHost: 'x')
            .props['link'],
        'meel_guide');
    expect(
        const PlayerMoveEnded(
          index: 0,
          movementId: 1,
          playedSeconds: 1,
          plannedSeconds: 1,
          reachedPct: 100,
          repsReached: 1,
          repsPlanned: 1,
          pauses: 0,
          seeks: 0,
          how: MoveEndReason.playedToEnd,
        ).props['how'],
        'played_to_end');
  });

  test('the catalogue doc lists exactly the events in code', () {
    expect(_documentedNames(), samples.map((e) => e.name).toSet());
  });
}
