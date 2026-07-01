import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _titleCtrl,
          style: PTextStyles.of(context)
              .editFieldValue
              .copyWith(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Session title',
            border: InputBorder.none,
            hintStyle: TextStyle(fontFamily: PFonts.ui, color: colors.onFaint),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _canSave ? _save : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: _canSave ? cs.primary : colors.surface3,
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.center,
                child: Text('Save',
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: _canSave ? cs.onPrimary : colors.onFaint)),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: cs.primary,
          unselectedLabelColor: colors.onFaint,
          indicatorColor: cs.primary,
          dividerColor: colors.borderSoft,
          labelStyle: const TextStyle(
              fontFamily: PFonts.ui, fontWeight: FontWeight.w700, fontSize: 13),
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final items = _inSection(section);
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('No ${_sectionLabels[section]} exercises yet',
                      style: PTextStyles.of(context)
                          .cardDescription
                          .copyWith(color: colors.onFaint)))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorder: (o, n) => _reorderWithin(section, o, n),
                  itemBuilder: (context, i) =>
                      _itemTile(items[i], key: items[i].key),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addExercise(section),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.borderSoft),
                foregroundColor: colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text('Add exercise to ${_sectionLabels[section]}',
                  style: const TextStyle(
                      fontFamily: PFonts.ui, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemTile(_EditItem item, {required Key key}) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final isCustom = item.reps != item.exercise.repetitionsDefault;
    final stepFg = isCustom ? colors.repCustom : colors.repDefault;
    final stepBg = isCustom ? colors.repCustomBg : colors.repDefaultBg;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(item.exercise.name,
                  style: TextStyle(
                      fontFamily: PFonts.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: cs.onSurface)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, size: 20, color: colors.onFaint),
              onPressed: () => _remove(item),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            // Rep stepper — green (default) / orange (customised), like the
            // flat editor.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: stepBg, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _RepBtn(
                    label: '−', color: stepFg, onTap: () => _setReps(item, -1)),
                SizedBox(
                  width: 34,
                  child: Text('${item.reps}',
                      textAlign: TextAlign.center,
                      style: PTextStyles.of(context)
                          .stepperNumber
                          .copyWith(color: stepFg)),
                ),
                _RepBtn(
                    label: '+', color: stepFg, onTap: () => _setReps(item, 1)),
              ]),
            ),
            const Spacer(),
            // Section reassignment.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSoft),
              ),
              child: DropdownButton<TrainingSection>(
                value: item.section,
                underline: const SizedBox.shrink(),
                isDense: true,
                icon: Icon(Icons.expand_more_rounded, color: colors.onMuted),
                dropdownColor: colors.surface2,
                style: TextStyle(
                    fontFamily: PFonts.ui,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface),
                onChanged: (s) => s == null ? null : _moveToSection(item, s),
                items: [
                  for (final d in _disciplines)
                    DropdownMenuItem(value: d, child: Text(_sectionLabels[d]!)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            ReorderableDragStartListener(
              index: _inSection(item.section).indexOf(item),
              child: Icon(Icons.drag_handle_rounded, color: colors.onFaint),
            ),
          ]),
        ],
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.tealBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_items.length} exercises',
                  style: TextStyle(
                      fontFamily: PFonts.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: colors.teal)),
              const SizedBox(height: 6),
              Text(
                  allKnown
                      ? 'Total ≈ $minutes min'
                      : 'Total ≈ $minutes min (some track lengths unknown)',
                  style: TextStyle(
                      fontFamily: PFonts.ui,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.teal)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('BREAKDOWN',
            style: PTextStyles.of(context)
                .sectionLabel
                .copyWith(color: colors.onFaint)),
        const SizedBox(height: 10),
        for (final d in _disciplines)
          if (_inSection(d).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_sectionLabels[d]!,
                      style: TextStyle(
                          fontFamily: PFonts.ui,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  Text('${_inSection(d).length}',
                      style: TextStyle(
                          fontFamily: PFonts.ui,
                          fontWeight: FontWeight.w700,
                          color: colors.onMuted)),
                ],
              ),
            ),
      ],
    );
  }
}

class _RepBtn extends StatelessWidget {
  const _RepBtn(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontFamily: PFonts.ui,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                color: color,
                height: 1)),
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: exercises.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No exercises available',
                    style: TextStyle(
                        fontFamily: PFonts.ui, color: colors.onMuted)),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Text('Add an exercise',
                        style: PTextStyles.of(context)
                            .dialogTitle
                            .copyWith(color: cs.onSurface)),
                  ),
                  for (final e in exercises)
                    ListTile(
                      title: Text(e.name,
                          style: TextStyle(
                              fontFamily: PFonts.ui,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                      subtitle: e.titleFa != null
                          ? Text(e.titleFa!,
                              style: TextStyle(
                                  fontFamily: PFonts.farsi,
                                  color: colors.onFaint))
                          : null,
                      onTap: () => Navigator.pop(context, e),
                    ),
                ],
              ),
      ),
    );
  }
}
