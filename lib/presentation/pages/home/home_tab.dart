import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/info/info_link.dart';
import '../../../domain/entities/training_session/training_session.dart';
import '../../bloc/announcement/announcement_cubit.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../bloc/training_session/training_session_cubit.dart';
import '../progress/calendar_page.dart';
import '../session_flow/session_preview_page.dart';
import '../session_flow/session_start.dart';
import 'home_page.dart';

/// Wires [HomePage] to the app: sessions from [TrainingSessionCubit], the
/// play flow (preview → player), the calendar and the info card from
/// [AnnouncementCubit]. Expects a [TrainingHistoryCubit] and an
/// [AnnouncementCubit] above it.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  /// Opens the session's preview, then refreshes the history so a
  /// finished session shows on Home.
  Future<void> _openSession(
      BuildContext context, TrainingSession session) async {
    final history = context.read<TrainingHistoryCubit>();
    await openSessionPreview(context, session);
    await history.load();
  }

  /// Long-press on the Today card: Zoorkhaneh mode, then refresh history.
  Future<void> _openSessionMenu(
      BuildContext context, TrainingSession session) async {
    final history = context.read<TrainingHistoryCubit>();
    await showSessionPlayMenu(context, session);
    await history.load();
  }

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

  /// Opens the card's page in the browser (the content lives on our
  /// website, so it changes without an app release) and marks this version
  /// of the card as seen.
  Future<void> _openInfo(BuildContext context, InfoLink link) async {
    final announcement = context.read<AnnouncementCubit>();
    await launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
    await announcement.markSeen();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
        builder: (context, state) => _withAnnouncement(context, state),
      );

  Widget _withAnnouncement(BuildContext context, TrainingSessionState state) =>
      BlocBuilder<AnnouncementCubit, AnnouncementState>(
        builder: (context, announcement) => HomePage(
          sessions: homeSessionsFrom(state),
          onOpenSession: (s) => _openSession(context, s),
          onSessionMenu: (s) => _openSessionMenu(context, s),
          onOpenCalendar: () => _openCalendar(context),
          infoLink: announcement.link,
          infoIsNew: announcement.isNew,
          onOpenInfo: (link) => _openInfo(context, link),
        ),
      );
}
