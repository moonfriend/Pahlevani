import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/training_session/training_session.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../bloc/training_session/training_session_cubit.dart';
import '../progress/calendar_page.dart';
import '../session_flow/session_preview_page.dart';
import '../shell/app_shell.dart';
import '../training_session/training_sessions_page.dart';
import 'home_page.dart';

/// Wires [HomePage] to the app: sessions from [TrainingSessionCubit], the
/// existing play flow (mode dialog → player) and the full session list.
/// Expects a [TrainingHistoryCubit] above it.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  /// Index of the Progress tab in the shell.
  static const progressTab = 2;

  /// Opens the session's preview, then refreshes the history so a
  /// finished session shows on Home.
  Future<void> _openSession(
      BuildContext context, TrainingSession session) async {
    final history = context.read<TrainingHistoryCubit>();
    await openSessionPreview(context, session);
    await history.load();
  }

  void _openAllSessions(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(
          // The list was always a root page; give it a way back.
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('All sessions')),
            body: const TrainingSessionPage(),
          ),
        ),
      );

  void _openCalendar(BuildContext context) {
    final history = context.read<TrainingHistoryCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: history, child: const CalendarPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
        builder: (context, state) => HomePage(
          sessions: homeSessionsFrom(state),
          onOpenSession: (s) => _openSession(context, s),
          onOpenAllSessions: () => _openAllSessions(context),
          onOpenProgress: () => AppShell.of(context).select(progressTab),
          onOpenCalendar: () => _openCalendar(context),
        ),
      );
}
