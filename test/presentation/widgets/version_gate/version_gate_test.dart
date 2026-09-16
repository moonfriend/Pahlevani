import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/release/version_gate_config.dart';
import 'package:pahlevani/presentation/bloc/version_gate/version_gate_cubit.dart';
import 'package:pahlevani/presentation/widgets/version_gate/version_gate.dart';

import '../../../fakes/fake_version_gate_repository.dart';

Widget _harness(VersionGateCubit cubit) => BlocProvider.value(
      value: cubit,
      child: const MaterialApp(
        home: VersionGate(child: Text('APP CONTENT')),
      ),
    );

void main() {
  testWidgets('shows the child when the gate is not blocked', (tester) async {
    final repo = FakeVersionGateRepository();
    final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 1);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.text('APP CONTENT'), findsOneWidget);
  });

  testWidgets('shows the blocking screen instead of the child when blocked',
      (tester) async {
    final repo = FakeVersionGateRepository()
      ..config = const VersionGateConfig(
          minSupportedBuildNumber: 10,
          updateMessage: 'Time to update!',
          forceUpdate: true);
    final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 1);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.text('APP CONTENT'), findsNothing);
    expect(find.text('Time to update!'), findsOneWidget);
  });

  testWidgets('re-checks the gate when the app resumes from the background',
      (tester) async {
    final repo = FakeVersionGateRepository();
    final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 1);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();
    expect(find.text('APP CONTENT'), findsOneWidget);

    // Server-side config changes to blocking while the app sits in the
    // background — nothing re-runs the check on its own from here.
    repo.config = const VersionGateConfig(
        minSupportedBuildNumber: 10,
        updateMessage: 'Please update now!',
        forceUpdate: true);

    // Simulate the app returning to the foreground (e.g. reopened from the
    // launcher without the process having been killed).
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.text('APP CONTENT'), findsNothing);
    expect(find.text('Please update now!'), findsOneWidget);
  });
}
