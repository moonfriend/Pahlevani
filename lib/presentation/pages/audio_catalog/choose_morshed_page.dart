import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';

/// Lets the athlete pick one musician ("Morshed") whose recordings play for
/// every movement, everywhere — a total override, not a per-movement choice.
class ChooseMorshedPage extends StatefulWidget {
  const ChooseMorshedPage({super.key});

  @override
  State<ChooseMorshedPage> createState() => _ChooseMorshedPageState();
}

class _ChooseMorshedPageState extends State<ChooseMorshedPage> {
  @override
  void initState() {
    super.initState();
    context.read<AudioCatalogCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Choose your Morshed')),
      body: BlocBuilder<AudioCatalogCubit, AudioCatalogState>(
        builder: (context, state) {
          return switch (state) {
            AudioCatalogLoading() =>
              const Center(child: CircularProgressIndicator()),
            AudioCatalogError(:final message) => Center(child: Text(message)),
            AudioCatalogLoaded(:final musicians, :final selectedMusicianId) =>
              musicians.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No musicians yet — check back once some have been added.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: musicians.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: colors.borderSoft),
                      itemBuilder: (context, i) => _MusicianTile(
                        musician: musicians[i],
                        selected: musicians[i].id == selectedMusicianId,
                      ),
                    ),
          };
        },
      ),
    );
  }
}

class _MusicianTile extends StatelessWidget {
  const _MusicianTile({required this.musician, required this.selected});
  final Musician musician;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final hasPhoto = musician.photoUrl != null && musician.photoUrl!.isNotEmpty;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.surface3,
        backgroundImage: hasPhoto ? NetworkImage(musician.photoUrl!) : null,
        child: hasPhoto
            ? null
            : Text(
                musician.name.isNotEmpty ? musician.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: colors.onMuted, fontWeight: FontWeight.w700),
              ),
      ),
      title: Text(musician.name),
      trailing:
          selected ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
      onTap: () =>
          context.read<AudioCatalogCubit>().selectMusician(musician.id),
    );
  }
}
