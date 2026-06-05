import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';

class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({super.key});

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  void _navigateToPlayer(BuildContext context, TrainingSession trainingSession) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioPlayerPage(trainingSession: trainingSession),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.98),
      appBar: AppBar(
        title: const Text('Select a TrainingSession', style: TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
        builder: (context, state) {
          Widget bodyContent;

          if (state is TrainingSessionInitial || (state is TrainingSessionLoading && state.uiModel.trainingSessions.isEmpty)) {
            bodyContent = const Center(child: CircularProgressIndicator());
          } else if (state is TrainingSessionError) {
            bodyContent = _buildErrorWidget(context, state.message);
          } else {
            List<TrainingSession> training_sessions = [];
            Map<int, DownloadStatus> downloadStatus = {};
            Map<int, double> downloadProgress = {};
            Map<int, int> itemCounts = {};
            Map<int, int> sessionDurations = {};

            if (state is TrainingSessionLoading) {
              training_sessions = state.uiModel.trainingSessions;
              downloadStatus = state.uiModel.downloadStatuses;
              itemCounts = state.uiModel.sessionItemCounts;
              sessionDurations = state.uiModel.sessionDurations;
            } else if (state is TrainingSessionLoaded) {
              training_sessions = state.uiModel.trainingSessions;
              downloadStatus = state.uiModel.downloadStatuses;
              itemCounts = state.uiModel.sessionItemCounts;
              sessionDurations = state.uiModel.sessionDurations;
            } else if (state is TrainingSessionDownloading) {
              training_sessions = state.uiModel.trainingSessions;
              downloadStatus = state.uiModel.downloadStatuses;
              downloadProgress = state.downloadProgress;
              itemCounts = state.uiModel.sessionItemCounts;
              sessionDurations = state.uiModel.sessionDurations;
            }

            if (training_sessions.isEmpty && state is! TrainingSessionLoading) {
              bodyContent = _buildEmptyListWidget(context);
            } else {
              bodyContent = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: _buildTrainingSessionListView(
                  context,
                  training_sessions,
                  downloadStatus,
                  downloadProgress,
                  itemCounts,
                  sessionDurations,
                  theme,
                ),
              );
            }
          }

          return RefreshIndicator(
            onRefresh: () => context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true),
            child: bodyContent,
          );
        },
      ),
    );
  }

  // --- UI Building Helper Widgets ---

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _buildTrainingSessionListView(
    BuildContext context,
    List<TrainingSession> training_sessions,
    Map<int, DownloadStatus> downloadStatus,
    Map<int, double> downloadProgress,
    Map<int, int> itemCounts,
    Map<int, int> sessionDurations,
    ThemeData theme,
  ) {
    return ListView.builder(
      itemCount: training_sessions.length,
      itemBuilder: (context, index) {
        final training_session = training_sessions[index];
        final status = downloadStatus[training_session.id] ?? DownloadStatus.notDownloaded;
        final progress = downloadProgress[training_session.id];
        final trackCount = itemCounts[training_session.id] ?? 0;
        final durationSeconds = sessionDurations[training_session.id];

        return Card(
          key: ValueKey(training_session.id),
          color: theme.colorScheme.surface.withValues(alpha: 0.97),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            leading: Stack(
              alignment: Alignment.topRight,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.queue_music_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                if (training_session.isUserCreated)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.person, color: Colors.green, size: 16),
                  ),
              ],
            ),
            title: Text(
              training_session.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (training_session.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, bottom: 4),
                    child: Text(
                      training_session.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  // child: Row(
                    children: [
                      if (status == DownloadStatus.downloaded)
                        const Icon(Icons.done, color: Colors.green, size: 20),
                      // const SizedBox(width: 4),
                      Icon(Icons.music_note_rounded, size: 16, color: theme.colorScheme.primary),
                      Text('$trackCount tracks', style: theme.textTheme.bodySmall),
                      if (durationSeconds != null) ...[
                        Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.primary),
                        Text(_formatDuration(durationSeconds), style: theme.textTheme.bodySmall),
                      ],
                      // const SizedBox(width: 16),
                      Icon(Icons.bolt_rounded, size: 16, color: theme.colorScheme.secondary),
                      // const SizedBox(width: 4),
                      Text('Difficulty: ${training_session.difficulty}', style: theme.textTheme.bodySmall),
                      // const SizedBox(width: 8),
                      if (training_session.isUserCreated)
                        const Icon(Icons.person, color: Colors.green, size: 18)
                      else
                        const Icon(Icons.cloud, color: Colors.grey, size: 18),
                    ],
                  // ),
                ),
                if (status == DownloadStatus.downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: LinearProgressIndicator(
                      value: progress ?? 0,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditTrainingSession(context, training_session);
                } else if (value == 'delete') {
                  _deleteTrainingSession(context, training_session);
                } else if (value == 'download') {
                  context.read<TrainingSessionCubit>().downloadTrainingSession(training_session.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit TrainingSession'),
                    ],
                  ),
                ),
                if (status != DownloadStatus.downloaded)
                const PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text('Download'),
                    ],
                  ),
                ),
                if (training_session.isUserCreated)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete TrainingSession', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
            onTap: () => _navigateToPlayer(context, training_session),
          ),
        );
      },
    );
  }

  Future<void> _navigateToEditTrainingSession(
      BuildContext context, TrainingSession trainingSession) async {
    final cubit = context.read<TrainingSessionCubit>();
    final sessionDetail = cubit.getSessionDetail(trainingSession.id);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditTrainingSessionPage(
          trainingSession: trainingSession,
          items: sessionDetail?.items ?? const [],
        ),
      ),
    );

    if (result != null && mounted) {
      final updatedSession = result['session'] as TrainingSession;
      final items = result['items'] as List<ItemDetail>?;
      cubit.updateTrainingSession(updatedSession, items: items);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updatedSession.title} updated'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteTrainingSession(BuildContext context, TrainingSession trainingSession) async {
    final cubit = context.read<TrainingSessionCubit>();
    try {
      await cubit.deleteTrainingSession(trainingSession.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${trainingSession.title} deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Widget _buildErrorWidget(BuildContext context, String message) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            // Refresh triggers cubit fetch
            onPressed: () => context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'))
      ]),
    ));
  }

  Widget _buildEmptyListWidget(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No training_sessions found.'),
      const SizedBox(height: 16),
      ElevatedButton.icon(
          // Refresh triggers cubit fetch
          onPressed: () => context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'))
    ]));
  }
}
