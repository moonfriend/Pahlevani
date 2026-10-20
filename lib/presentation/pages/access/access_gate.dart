import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../domain/entities/auth/app_user.dart';
import '../../bloc/activation/activation_cubit.dart';
import '../../bloc/auth/auth_cubit.dart';
import 'account_page.dart';
import 'consent_page.dart';
import 'locked_page.dart';

/// The release-1 gate in front of the app: an account, the safety and
/// privacy consent, then an activation code (Patreon members only).
///
/// Signed out → [AccountPage]; signed in without consent → [ConsentPage];
/// without activation → [LockedPage]; activated → [child]. The server
/// enforces the same rule on every read (migration 0045), so this screen is
/// the explanation, not the protection. [onActivated] runs when the account
/// becomes active, to fetch the content the server now returns.
class AccessGate extends StatelessWidget {
  const AccessGate({super.key, required this.child, required this.onActivated});

  final Widget child;
  final VoidCallback onActivated;

  /// The state that decides the screen: a failure or a submit in progress
  /// keeps showing the screen it happened on.
  static AuthState _settled(AuthState state) => switch (state) {
        AuthFailure(:final previous) => _settled(previous),
        AuthSubmitting() => const AuthAnonymous(),
        _ => state,
      };

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (a, b) => _settled(a) != _settled(b),
        builder: (context, state) => switch (_settled(state)) {
          AuthChecking() => const _Blank(),
          AuthNeedsConsent() => const ConsentPage(),
          AuthAuthenticated(:final user) => _ActivationScope(
              key: ValueKey(user.id),
              user: user,
              onActivated: onActivated,
              child: child,
            ),
          _ => const AccountPage(),
        },
      );
}

/// Checks the signed-in account once, then shows the app or the locked page.
class _ActivationScope extends StatefulWidget {
  const _ActivationScope({
    super.key,
    required this.user,
    required this.onActivated,
    required this.child,
  });

  final AppUser user;
  final VoidCallback onActivated;
  final Widget child;

  @override
  State<_ActivationScope> createState() => _ActivationScopeState();
}

class _ActivationScopeState extends State<_ActivationScope> {
  @override
  void initState() {
    super.initState();
    context.read<ActivationCubit>().check(widget.user.id);
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ActivationCubit, ActivationState>(
        listenWhen: (a, b) => a is! ActivationActive && b is ActivationActive,
        listener: (_, __) => widget.onActivated(),
        builder: (context, state) => switch (state) {
          ActivationChecking() => const _Blank(),
          ActivationLocked() => LockedPage(email: widget.user.email),
          ActivationActive() => widget.child,
        },
      );
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).extension<KashiColors>()!.ground,
        child: const SizedBox.expand(),
      );
}
