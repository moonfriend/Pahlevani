import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/kashi/kashi_colors.dart';
import '../bloc/first_run/first_run_cubit.dart';
import '../bloc/first_run/first_run_state.dart';
import '../pages/splash/splash_page.dart';

/// Shows the splash on first open, otherwise [child].
///
/// Swaps in place rather than pushing a route, so Back can never return to
/// the splash.
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
            SplashPage(onBegin: context.read<FirstRunCubit>().complete),
          FirstRunDone() => child,
        },
      );
}
