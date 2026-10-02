import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../bloc/settings/settings_cubit.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../widgets/kashi/kashi_labels.dart';
import '../../widgets/kashi/kashi_month_calendar.dart';
import '../../widgets/kashi/kashi_segmented.dart';
import '../../widgets/kashi/khatam_window.dart';

/// Language, appearance and morshed voice.
///
/// Appearance and morshed are real settings ([SettingsCubit],
/// [AudioCatalogCubit]). Language is a placeholder until localisation
/// exists; the name falls back to "Pahlevan" for anonymous users.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// A figure per visit, as the design picks one per session.
  late final _figure = math.Random().nextBool()
      ? KashiAssets.pahlevanMale
      : KashiAssets.pahlevanFemale;

  void _comingSoon(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              children: [
                _header(colors),
                _section(
                  'Language',
                  KashiSegmented<String>(
                    options: const [('en', 'English'), ('fa', 'فارسی')],
                    selected: 'en',
                    onSelected: (value) {
                      if (value == 'fa') {
                        _comingSoon('فارسی arrives with the translations.');
                      }
                    },
                  ),
                ),
                _section(
                  'Appearance',
                  KashiSegmented<ThemeMode>(
                    options: const [
                      (ThemeMode.system, 'System'),
                      (ThemeMode.light, 'Light'),
                      (ThemeMode.dark, 'Dark'),
                    ],
                    selected: context.watch<SettingsCubit>().state.themeMode,
                    onSelected: context.read<SettingsCubit>().setThemeMode,
                  ),
                ),
                _section('Morshed voice', _morshedPicker(colors)),
                const SizedBox(height: 22),
                Text(
                  'Your trainers choose which moves are counted.',
                  style: KashiTextStyles.body.copyWith(
                      fontSize: 12.5, height: 1.55, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(KashiColors colors) {
    final auth = context.watch<AuthCubit>().state;
    final email = auth is AuthAuthenticated ? auth.user.email : null;
    final name = (email != null && email.contains('@'))
        ? email.split('@').first
        : 'Pahlevan';

    final history = context.watch<TrainingHistoryCubit>().state;
    final completions = history is TrainingHistoryLoaded
        ? history.completions.map((c) => c.completedAt).toList()
        : const <DateTime>[];
    final String subtitle;
    if (completions.isEmpty) {
      subtitle = 'No sessions yet';
    } else {
      final first = completions.reduce((a, b) => a.isBefore(b) ? a : b);
      subtitle = '${completions.length} sessions since '
          '${kashiMonthLabel(first).split(' ').first}';
    }

    return Row(
      children: [
        KhatamWindow(
          size: 72,
          frameWidth: 5,
          frameColor: colors.reward,
          background: colors.tile,
          child: Transform.scale(
            scale: 1.25,
            child: Image.asset(_figure, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KashiTextStyles.title
                      .copyWith(fontSize: 22, color: colors.textPrimary)),
              Text(subtitle,
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String label, Widget control) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KashiSectionLabel(label),
            const SizedBox(height: 8),
            control,
          ],
        ),
      );

  /// Segments for up to three morsheds (the design); a list beyond that so
  /// names never get squeezed.
  Widget _morshedPicker(KashiColors colors) {
    final state = context.watch<AudioCatalogCubit>().state;
    final catalog = context.read<AudioCatalogCubit>();
    return switch (state) {
      AudioCatalogLoading() => _note('Loading…', colors),
      AudioCatalogError() =>
        _note('Morsheds are unavailable right now.', colors),
      AudioCatalogLoaded(:final morsheds) when morsheds.isEmpty =>
        _note('No morsheds yet.', colors),
      AudioCatalogLoaded(:final morsheds, :final selectedMorshedId)
          when morsheds.length <= 3 =>
        KashiSegmented<int>(
          options: [for (final m in morsheds) (m.id, m.name)],
          selected: selectedMorshedId,
          onSelected: catalog.selectMorshed,
        ),
      AudioCatalogLoaded(:final morsheds, :final selectedMorshedId) => Column(
          children: [
            for (final m in morsheds)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: KashiSegmented<int>(
                  options: [(m.id, m.name)],
                  selected: selectedMorshedId,
                  onSelected: catalog.selectMorshed,
                ),
              ),
          ],
        ),
    };
  }

  Widget _note(String text, KashiColors colors) => Text(text,
      style:
          KashiTextStyles.body.copyWith(fontSize: 13, color: colors.textMuted));
}
