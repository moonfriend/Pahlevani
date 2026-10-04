import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../home/home_tab.dart';
import '../library/library_page.dart';
import '../profile/profile_page.dart';
import '../progress/progress_page.dart';
import 'app_shell.dart';

/// The app's four tabs. Services are looked up lazily, when a tab is first
/// shown. The full session list opens from Home's "All sessions".
List<ShellTab> mainTabs() => [
      ShellTab(
        label: 'Home',
        builder: (_) => BlocProvider.value(
          value: _history()..load(),
          child: const HomeTab(),
        ),
        onSelected: () => _history().load(),
      ),
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
