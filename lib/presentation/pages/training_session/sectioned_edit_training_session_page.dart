import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/session_duration.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

/// English tab labels for the discipline sections (the enum's [displayName] is
/// Farsi, used elsewhere in the trainee-facing UI).
const _sectionLabels = <TrainingSection, String>{
  TrainingSection.warmUp: 'Warm up',
  TrainingSection.sheno: 'Sheno',
  TrainingSection.mobility: 'Mobility',
  TrainingSection.meel: 'Meel',
  TrainingSection.charkh: 'Charkh',
  TrainingSection.kabbade: 'Kabbade',
  TrainingSection.sang: 'Sang',
  TrainingSection.other: 'Other',
};

/// Discipline tabs, in play order. "Other" is always present so unsectioned or
/// legacy items are never hidden and can be moved into a discipline.
const _disciplines = <TrainingSection>[
  TrainingSection.warmUp,
  TrainingSection.sheno,
  TrainingSection.mobility,
  TrainingSection.meel,
  TrainingSection.charkh,
  TrainingSection.kabbade,
  TrainingSection.sang,
  TrainingSection.other,
];

/// A single editable row: an exercise with a mutable rep count and section.
class _EditItem {
  _EditItem({
    required this.key,
    required this.exercise,
    required this.reps,
    required this.section,
  });

  final Key key;
  final Exercise exercise;
  int reps;
  TrainingSection section;
}

/// Trainer's section-tabbed session editor. One tab per Pahlevani discipline
/// plus a Summary tab showing the total length. Returns
/// `{'session': TrainingSession, 'items': List<ItemDetail>}` on save (same
/// contract as the flat editor) with each item's [TrainingSection] preserved.
class SectionedEditTrainingSessionPage extends StatefulWidget {
  const SectionedEditTrainingSessionPage({
    super.key,
    required this.trainingSession,
    required this.items,
    required this.availableExercises,
  });

  final TrainingSession trainingSession;
  final List<ItemDetail> items;
  final List<Exercise> availableExercises;

  @override
  State<SectionedEditTrainingSessionPage> createState() =>
      _SectionedEditTrainingSessionPageState();
}

class _SectionedEditTrainingSessionPageState
    extends State<SectionedEditTrainingSessionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: _disciplines.length + 1, vsync: this);
  late final TextEditingController _titleCtrl;
  late final List<_EditItem> _items;
  int _keySeed = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.trainingSession.title)
      ..addListener(() => setState(() {}));
    _items = [
      for (final d in widget.items)
        _EditItem(
          key: ValueKey('seed-${d.item.exerciseId}-${_keySeed++}'),
          exercise: d.exercise,
          reps: d.item.prescription is RepsPresc
              ? (d.item.prescription as RepsPresc).count
              : d.exercise.repetitionsDefault,
          section: d.item.section,
        ),
    ];
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty && _items.isNotEmpty;

  List<_EditItem> _inSection(TrainingSection s) =>
      _items.where((e) => e.section == s).toList();

  void _setReps(_EditItem item, int delta) {
    setState(() => item.reps = (item.reps + delta).clamp(1, 99));
  }

  void _remove(_EditItem item) => setState(() => _items.remove(item));

  void _moveToSection(_EditItem item, TrainingSection section) {
    setState(() => item.section = section);
  }

  /// Reorders items *within* one discipline, leaving other sections untouched.
  void _reorderWithin(TrainingSection s, int oldIndex, int newIndex) {
    setState(() {
      final section = _inSection(s);
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = section.removeAt(oldIndex);
      section.insert(newIndex, moved);
      // Rebuild the master list: pour the reordered section back into the
      // positions previously occupied by that section; keep others in place.
      final queue = List<_EditItem>.from(section);
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].section == s) _items[i] = queue.removeAt(0);
      }
    });
  }

  Future<void> _addExercise(TrainingSection section) async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExercisePicker(exercises: widget.availableExercises),
    );
    if (exercise == null) return;
    setState(() {
      _items.add(_EditItem(
        key: ValueKey('add-${exercise.id}-${_keySeed++}'),
        exercise: exercise,
        reps: exercise.repetitionsDefault,
        section: section,
      ));
    });
  }

  void _save() {
    if (!_canSave) return;
    // Flatten in discipline order so the play sequence follows the tabs.
    final ordered = <_EditItem>[
      for (final d in _disciplines) ..._inSection(d),
    ];
    final items = ordered.asMap().entries.map((e) {
      final pos = e.key;
      final item = e.value;
      return ItemDetail(
        item: TrainingItem(
          id: widget.trainingSession.id * 10000 + pos,
          sessionId: widget.trainingSession.id,
          exerciseId: item.exercise.id,
          position: pos,
          prescription: RepsPresc(item.reps),
          section: item.section,
        ),
        exercise: item.exercise,
      );
    }).toList();

    Navigator.pop(context, {
      'session': widget.trainingSession.copyWith(
        title: _titleCtrl.text.trim(),
        isUserCreated: true,
      ),
      'items': items,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            hintText: 'Session title',
            border: InputBorder.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final d in _disciplines)
              Tab(text: '${_sectionLabels[d]} (${_inSection(d).length})'),
            const Tab(text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final d in _disciplines) _sectionTab(d),
          _summaryTab(),
        ],
      ),
    );
  }

  Widget _sectionTab(TrainingSection section) {
    final items = _inSection(section);
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('No ${_sectionLabels[section]} exercises yet',
                      style: Theme.of(context).textTheme.bodyMedium))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: items.length,
                  onReorder: (o, n) => _reorderWithin(section, o, n),
                  itemBuilder: (context, i) =>
                      _itemTile(items[i], key: items[i].key),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addExercise(section),
              icon: const Icon(Icons.add),
              label: Text('Add exercise to ${_sectionLabels[section]}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemTile(_EditItem item, {required Key key}) {
    return ListTile(
      key: key,
      title: Text(item.exercise.name),
      subtitle: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _setReps(item, -1),
          ),
          Text('${item.reps} reps'),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _setReps(item, 1),
          ),
          const SizedBox(width: 8),
          DropdownButton<TrainingSection>(
            value: item.section,
            underline: const SizedBox.shrink(),
            onChanged: (s) => s == null ? null : _moveToSection(item, s),
            items: [
              for (final d in _disciplines)
                DropdownMenuItem(value: d, child: Text(_sectionLabels[d]!)),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _remove(item),
      ),
    );
  }

  Widget _summaryTab() {
    var total = 0;
    var allKnown = true;
    for (final item in _items) {
      final seconds = trackDurationSeconds(
        audioSeconds: item.exercise.durationSeconds,
        defaultReps: item.exercise.repetitionsDefault,
        reps: item.reps,
      );
      if (seconds == null) {
        allKnown = false;
        continue;
      }
      total += seconds;
    }
    final minutes = (total / 60).ceil();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('${_items.length} exercises'),
          const SizedBox(height: 8),
          Text(allKnown
              ? 'Total ≈ $minutes min'
              : 'Total ≈ $minutes min (some track lengths unknown)'),
          const SizedBox(height: 24),
          for (final d in _disciplines)
            if (_inSection(d).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                    '${_sectionLabels[d]}: ${_inSection(d).length} exercises'),
              ),
        ],
      ),
    );
  }
}

/// Simple exercise catalogue picker: returns the chosen [Exercise] via pop.
class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker({required this.exercises});
  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: exercises.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No exercises available'),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Add an exercise',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                for (final e in exercises)
                  ListTile(
                    title: Text(e.name),
                    subtitle: e.titleFa != null ? Text(e.titleFa!) : null,
                    onTap: () => Navigator.pop(context, e),
                  ),
              ],
            ),
    );
  }
}
