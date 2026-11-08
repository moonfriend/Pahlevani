import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../widgets/kashi/kashi_tab_bar.dart';
import '../../widgets/kashi/khatam_window.dart';
import 'app_shell.dart';

/// Under the email in the account menu and on Profile.
const steadyLinkedLabel = 'Steady account linked';

/// The foot of the web side rail: the user's avatar, name and the number
/// of sessions they have finished. Tapping it opens the account menu: who
/// is signed in (and whether Steady is linked), Profile and Sign out.
/// Reads [AuthCubit] and [TrainingHistoryCubit] from the context.
class RailUser extends StatelessWidget {
  const RailUser({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Account',
      position: PopupMenuPosition.over,
      onSelected: (action) => switch (action) {
        _MenuAction.profile => AppShell.of(context).selectLabel('Profile'),
        _MenuAction.signOut => context.read<AuthCubit>().signOut(),
      },
      itemBuilder: (_) => [
        if (user?.email case final email?)
          PopupMenuItem<_MenuAction>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in as $email'),
                if (user!.hasSteady)
                  Text(steadyLinkedLabel,
                      style: KashiTextStyles.ui.copyWith(fontSize: 12)),
              ],
            ),
          ),
        if (user?.email != null) const PopupMenuDivider(),
        const PopupMenuItem(value: _MenuAction.profile, child: Text('Profile')),
        const PopupMenuItem(
            value: _MenuAction.signOut, child: Text('Sign out')),
      ],
      child: _summary(context, auth.displayName),
    );
  }

  Widget _summary(BuildContext context, String name) {
    final history = context.watch<TrainingHistoryCubit>().state;
    final sessions =
        history is TrainingHistoryLoaded ? history.completions.length : 0;
    return Row(
      children: [
        KhatamWindow(
          size: 40,
          frameWidth: 3,
          frameColor: KashiPalette.yellow400,
          background: KashiPalette.turquoise500,
          child: Transform.scale(
            scale: 1.25,
            child: Image.asset(KashiAssets.pahlevanFemale, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: KashiPalette.white)),
              Text(sessions == 1 ? '1 session' : '$sessions sessions',
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 12, color: KashiTabBar.inactiveLabelColor)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MenuAction { profile, signOut }
