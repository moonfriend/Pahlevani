import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/info/info_link.dart';
import '../../../domain/repositories/announcement_repository.dart';

class AnnouncementState extends Equatable {
  const AnnouncementState({this.link, this.isNew = false});

  /// Home's info card; null shows none.
  final InfoLink? link;

  /// The user hasn't opened this version yet: Home shows it raised.
  final bool isNew;

  @override
  List<Object?> get props => [link, isNew];
}

/// Home's info card: the cached copy first, then the server's, re-checked
/// every [refreshEvery] while the app runs (the web app can stay open for
/// days). A version the user hasn't opened is new until they open it.
class AnnouncementCubit extends Cubit<AnnouncementState> {
  AnnouncementCubit({required AnnouncementRepository repository})
      : _repo = repository,
        super(const AnnouncementState());

  static const refreshEvery = Duration(hours: 3);

  final AnnouncementRepository _repo;
  Timer? _timer;

  /// On app start: show the cached card, fetch the current one, and keep
  /// re-checking.
  Future<void> load() async {
    await _show(await _repo.cached());
    await refresh();
    _timer ??= Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
  }

  /// Fetches the current card; offline, the shown one stays.
  Future<void> refresh() async {
    try {
      await _show(await _repo.refresh());
    } catch (error) {
      AppLogger.w('Home card refresh failed — keeping the last one',
          error: error);
    }
  }

  /// The user opened the card: this version is no longer new.
  Future<void> markSeen() async {
    final link = state.link;
    if (link == null) return;
    await _repo.markSeen(link.contentKey);
    if (!isClosed) emit(AnnouncementState(link: link));
  }

  Future<void> _show(InfoLink? link) async {
    final seen = await _repo.seenKey();
    if (isClosed) return;
    emit(AnnouncementState(
        link: link, isNew: link != null && link.contentKey != seen));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
