import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pahlevani/presentation/bloc/version_gate/version_gate_cubit.dart';
import 'package:pahlevani/presentation/widgets/version_gate/version_gate_screen.dart';

/// Wraps the app: runs the release-gate check once on startup, shows
/// [VersionGateScreen] if this install must update, otherwise [child].
/// Shows the child immediately while checking — the check fails open and is
/// expected to resolve quickly, so there's no need to hold the UI hostage
/// behind a spinner for the common (not-blocked) case.
class VersionGate extends StatefulWidget {
  const VersionGate({super.key, required this.child});
  final Widget child;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  @override
  void initState() {
    super.initState();
    context.read<VersionGateCubit>().check();
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
