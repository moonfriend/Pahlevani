import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/widgets/common/difficulty_pips.dart';

class EditTrainingSessionPage extends StatefulWidget {
  const EditTrainingSessionPage({
    super.key,
    required this.trainingSession,
    required this.items,
  });

  final TrainingSession trainingSession;
  final List<ItemDetail> items;

  @override
  State<EditTrainingSessionPage> createState() =>
      _EditTrainingSessionPageState();
}

class _EditTrainingSessionPageState extends State<EditTrainingSessionPage> {
  late List<ItemDetail> _items;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late int _difficulty;
  late Map<int, int> _repsMap;

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty && _items.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _titleCtrl = TextEditingController(text: widget.trainingSession.title)
      ..addListener(() => setState(() {}));
    _descCtrl = TextEditingController(text: widget.trainingSession.description);
    _difficulty = widget.trainingSession.difficulty;
    _repsMap = {
      for (final d in _items)
        d.item.exerciseId: d.item.prescription is RepsPresc
            ? (d.item.prescription as RepsPresc).count
            : 1,
    };
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _setReps(int exerciseId, int delta) {
    setState(() {
      final cur = _repsMap[exerciseId] ?? 1;
      _repsMap[exerciseId] = (cur + delta).clamp(1, 99);
    });
  }

  void _resetReps(int exerciseId, int defaultReps) {
    setState(() => _repsMap[exerciseId] = defaultReps);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _save() {
    if (!_canSave) return;
    final updatedItems = _items.asMap().entries.map((e) {
      final pos = e.key;
      final d = e.value;
      final reps = _repsMap[d.item.exerciseId] ?? 1;
      return ItemDetail(
        item: TrainingItem(
          id: widget.trainingSession.id * 10000 + pos,
          sessionId: widget.trainingSession.id,
          exerciseId: d.item.exerciseId,
          position: pos,
          prescription: RepsPresc(reps),
        ),
        exercise: d.exercise,
      );
    }).toList();

    final newId = widget.trainingSession.isUserCreated
        ? widget.trainingSession.id
        : DateTime.now().millisecondsSinceEpoch;

    Navigator.pop(context, {
      'session': widget.trainingSession.copyWith(
        id: newId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        difficulty: _difficulty,
        isUserCreated: true,
      ),
      'items': updatedItems,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final fromServer = !widget.trainingSession.isUserCreated;
    final isNew = widget.trainingSession.title.isEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── App bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSoft)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close_rounded,
                        size: 22, color: cs.onSurface)),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                isNew
                    ? 'New session'
                    : fromServer
                        ? 'Edit a copy'
                        : 'Edit session',
                style: TextStyle(
                    fontFamily: PFonts.ui,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: cs.onSurface),
              )),
              // Save pill button
              GestureDetector(
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
            ]),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
              children: [
                // Teal info banner for server sessions
                if (fromServer) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: colors.tealBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: colors.teal),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                            'This is a built-in session. Saving creates your own editable copy — it won\'t change the original.',
                            style: TextStyle(
                                fontFamily: PFonts.ui,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: colors.teal,
                                height: 1.45),
                          )),
                        ]),
                  ),
                  const SizedBox(height: 18),
                ],

                // Title
                _Field(
                    label: 'Title',
                    child: TextField(
                      controller: _titleCtrl,
                      style: PTextStyles.of(context)
                          .editFieldValue
                          .copyWith(color: cs.onSurface),
                      decoration:
                          const InputDecoration(hintText: 'Session name'),
                    )),

                // Description
                _Field(
                    label: 'Description',
                    child: TextField(
                      controller: _descCtrl,
                      style: PTextStyles.of(context)
                          .editFieldValue
                          .copyWith(color: cs.onSurface),
                      decoration: const InputDecoration(
                          hintText: 'What is this session for?'),
                      maxLines: 3,
                    )),

                // Difficulty
                _Field(
                  label: 'Difficulty',
                  child: Row(children: [
                    DifficultySelector(
                      value: _difficulty,
                      onChanged: (v) => setState(() => _difficulty = v),
                    ),
                    const SizedBox(width: 12),
                    Text('$_difficulty / 5',
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: colors.onMuted)),
                  ]),
                ),

                // Exercises section header
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('EXERCISES · ${_items.length}'.toUpperCase(),
                          style: PTextStyles.of(context)
                              .sectionLabel
                              .copyWith(color: colors.onFaint)),
                      Text('drag to reorder',
                          style: TextStyle(
                              fontFamily: PFonts.ui,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: colors.onFaint)),
                    ],
                  ),
                ),

                // Reorderable exercise list
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  onReorder: _reorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, i) {
                    final detail = _items[i];
                    final ex = detail.exercise;
                    final exerciseId = ex.id;
                    final reps = _repsMap[exerciseId] ?? 1;
                    final defaultReps = ex.repetitionsDefault;
                    final isCustom = reps != defaultReps;
                    final stepFg =
                        isCustom ? colors.repCustom : colors.repDefault;
                    final stepBg =
                        isCustom ? colors.repCustomBg : colors.repDefaultBg;

                    return Container(
                      key: ValueKey('ex-$exerciseId-$i'),
                      height: 68,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Row(children: [
                        // Drag handle (6-dot grip)
                        ReorderableDragStartListener(
                          index: i,
                          child: SizedBox(
                            width: 40,
                            child:
                                Center(child: _DragGrip(color: colors.onFaint)),
                          ),
                        ),
                        // Name + Farsi + gloss
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(children: [
                              Flexible(
                                  child: Text(ex.name,
                                      style: TextStyle(
                                          fontFamily: PFonts.ui,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: cs.onSurface),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              if (ex.titleFa != null) ...[
                                const SizedBox(width: 7),
                                Text(ex.titleFa!,
                                    style: TextStyle(
                                        fontFamily: PFonts.farsi,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: colors.onFaint),
                                    textDirection: TextDirection.rtl),
                              ],
                            ]),
                            if (ex.gloss != null)
                              Text(ex.gloss!,
                                  style: TextStyle(
                                      fontFamily: PFonts.ui,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11.5,
                                      color: colors.onFaint)),
                          ],
                        )),
                        const SizedBox(width: 8),
                        // Rep stepper
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: stepBg,
                              borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _StepBtn(
                                label: '−',
                                color: stepFg,
                                onTap: () => _setReps(exerciseId, -1)),
                            GestureDetector(
                              onTap: isCustom
                                  ? () => _resetReps(exerciseId, defaultReps)
                                  : null,
                              child: SizedBox(
                                width: 34,
                                child: Text('$reps',
                                    textAlign: TextAlign.center,
                                    style: PTextStyles.of(context)
                                        .stepperNumber
                                        .copyWith(color: stepFg)),
                              ),
                            ),
                            _StepBtn(
                                label: '+',
                                color: stepFg,
                                onTap: () => _setReps(exerciseId, 1)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                      ]),
                    );
                  },
                ),

                // Legend
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
                  child: Text.rich(TextSpan(
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontSize: 11.5,
                        color: colors.onFaint,
                        height: 1.5),
                    children: [
                      TextSpan(
                          text: 'Green ',
                          style: TextStyle(
                              color: colors.repDefault,
                              fontWeight: FontWeight.w700)),
                      const TextSpan(text: 'reps are the exercise default · '),
                      TextSpan(
                          text: 'orange ',
                          style: TextStyle(
                              color: colors.repCustom,
                              fontWeight: FontWeight.w700)),
                      const TextSpan(
                          text:
                              'means you\'ve customised it. Tap a custom number to reset.'),
                    ],
                  )),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(label,
              style: PTextStyles.of(context)
                  .editFieldLabel
                  .copyWith(color: colors.onMuted)),
        ),
        child,
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(
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

class _DragGrip extends StatelessWidget {
  const _DragGrip({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(18, 18),
        painter: _DotGridPainter(color: color),
      );
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const r = 1.5;
    for (final x in [5.0, 13.0]) {
      for (final y in [5.0, 9.0, 13.0]) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
