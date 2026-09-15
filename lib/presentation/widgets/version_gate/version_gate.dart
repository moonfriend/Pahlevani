import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pahlevani/presentation/bloc/version_gate/version_gate_cubit.dart';
import 'package:pahlevani/presentation/widgets/version_gate/version_gate_screen.dart';

/// Wraps the app: runs the release-gate check on startup AND every time the
/// app returns to the foreground, shows [VersionGateScreen] if this install
/// must update, otherwise [child]. Shows the child immediately while
/// checking — the check fails open and is expected to resolve quickly, so
/// there's no need to hold the UI hostage behind a spinner for the common
/// (not-blocked) case.
///
/// Re-checking on resume matters because Android frequently keeps an app's
/// process alive in the background — reopening it from the launcher or
/// recent-apps is then a lifecycle resume, not a fresh process start, so a
/// check that only ran in [initState] would never re-fire for most real
/// "restarts" a user performs (only an actual process kill — e.g. clearing
/// app data, or the OS reclaiming memory — guarantees a fresh [initState]).
class VersionGate extends StatefulWidget {
  const VersionGate({super.key, required this.child});
  final Widget child;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<VersionGateCubit>().check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<VersionGateCubit>().check();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionGateCubit, VersionGateState>(
      builder: (context, state) {
        if (state is VersionGateBlocked) {
          return VersionGateScreen(message: state.message);
        }
        return widget.child;
      },
    );
  }
}
