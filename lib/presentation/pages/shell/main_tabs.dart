import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../library/library_page.dart';
import '../profile/profile_page.dart';
import '../progress/progress_page.dart';
import '../training_session/training_sessions_page.dart';
import 'app_shell.dart';

/// The app's four tabs. Home is still the existing session list until the
/// Kashi Home (bento) is built; services are looked up lazily, when a tab is
/// first shown.
List<ShellTab> mainTabs() => [
      ShellTab(label: 'Home', builder: (_) => const TrainingSessionPage()),
      ShellTab(label: 'Library', builder: (_) => const LibraryPage()),
      ShellTab(
        label: 'Progress',
        builder: (_) => BlocProvider.value(
          value: _history()..load(),
          child: const ProgressPage(),
        ),
        onSelected: () => _history().load(),
      ),
      ShellTab(
        label: 'Profile',
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: _history()..load()),
            BlocProvider.value(value: getIt<AudioCatalogCubit>()..load()),
          ],
          child: const ProfilePage(),
        ),
        onSelected: () => _history().load(),
      ),
    ];

TrainingHistoryCubit _history() => getIt<TrainingHistoryCubit>();
