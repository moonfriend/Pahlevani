import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/kashi/kashi_colors.dart';
import '../bloc/first_run/first_run_cubit.dart';
import '../bloc/first_run/first_run_state.dart';
import '../pages/onboarding/onboarding_page.dart';
import '../pages/splash/splash_page.dart';

/// Shows the first-open flow (splash, then onboarding) once, otherwise
/// [child].
///
/// Swaps in place rather than pushing routes, so Back can never return to
/// the splash or onboarding.
class FirstRunGate extends StatelessWidget {
  const FirstRunGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<FirstRunCubit, FirstRunState>(
        builder: (context, state) => switch (state) {
          FirstRunChecking() => ColoredBox(
              color: Theme.of(context).extension<KashiColors>()!.ground,
              child: const SizedBox.expand(),
            ),
          FirstRunPending() =>
            _FirstOpenFlow(onFinished: context.read<FirstRunCubit>().complete),
          FirstRunDone() => child,
        },
      );
}

/// Splash → Begin → onboarding → Skip/Begin → [onFinished]. First open only
/// counts as done once onboarding is left, so quitting mid-way shows the
/// splash again next time.
class _FirstOpenFlow extends StatefulWidget {
  const _FirstOpenFlow({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_FirstOpenFlow> createState() => _FirstOpenFlowState();
}

class _FirstOpenFlowState extends State<_FirstOpenFlow> {
  bool _onboarding = false;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _onboarding
            ? OnboardingPage(onFinished: widget.onFinished)
            : SplashPage(onBegin: () => setState(() => _onboarding = true)),
      );
}
