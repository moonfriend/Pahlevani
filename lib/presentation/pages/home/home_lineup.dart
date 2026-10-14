import 'home_page.dart';

/// What Home offers: one main card and up to two small ones.
typedef HomeLineup = ({
  HomeSession? main,
  bool mainFromTrainer,
  List<HomeSession> small,
});

/// Picks Home's sessions.
///
/// The admin sets the slots (`TrainingSession.homePosition`): 1 is the main
/// card, 2 and 3 the small ones. A session a trainer assigned to this user
/// (private, not theirs, not user-made) takes the main card; with several,
/// the newest. Before any slot is set, the first three public sessions
/// stand in, so Home is never empty.
HomeLineup homeLineup(List<HomeSession> sessions, {String? userId}) {
  final public = [
    for (final s in sessions)
      if (s.session.isPublic) s
  ];
  final assigned = [
    for (final s in sessions)
      if (!s.session.isPublic &&
          !s.session.isUserCreated &&
          s.session.ownerTrainerId != userId)
        s,
  ]..sort((a, b) {
      final at = a.session.createdAt, bt = b.session.createdAt;
      if (at == null || bt == null) return b.session.id.compareTo(a.session.id);
      return bt.compareTo(at);
    });

  HomeSession? slot(int position) {
    for (final s in public) {
      if (s.session.homePosition == position) return s;
    }
    return null;
  }

  final anySlot = public.any((s) => s.session.homePosition != null);
  final List<HomeSession> small;
  HomeSession? main;
  if (anySlot) {
    main = slot(1);
    small = [
      for (final p in const [2, 3])
        if (slot(p) case final s?) s,
    ];
  } else {
    main = public.isEmpty ? null : public.first;
    small = public.skip(1).take(2).toList();
  }
  if (assigned.isNotEmpty) {
    return (main: assigned.first, mainFromTrainer: true, small: small);
  }
  return (main: main, mainFromTrainer: false, small: small);
}
