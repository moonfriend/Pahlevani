import 'package:flutter/material.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/presentation/pages/trainer/student_detail_page.dart';

/// Trainer entry point (MVP): a single-student roster. The trainer is also the
/// student here, so the roster is seeded with the current user id — editable to
/// showcase the "enter a student, then open their plan" concept. Real
/// multi-student rosters arrive with the auth layer.
class TrainerStudentListPage extends StatefulWidget {
  const TrainerStudentListPage({super.key});

  @override
  State<TrainerStudentListPage> createState() => _TrainerStudentListPageState();
}

class _TrainerStudentListPageState extends State<TrainerStudentListPage> {
  final _controller = TextEditingController();
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final id = await getIt<CurrentUserService>().getUserId();
    if (!mounted) return;
    setState(() {
      _studentId = id;
      _controller.text = id;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;
    await getIt<CurrentUserService>().setUserId(id);
    if (!mounted) return;
    setState(() => _studentId = id);
  }

  void _openStudent(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailPage(studentId: id)),
    );
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
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text('Trainer · Students',
            style: PTextStyles.of(context)
                .appBarTitle
                .copyWith(color: cs.onSurface)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STUDENT ID',
                style: PTextStyles.of(context)
                    .sectionLabel
                    .copyWith(color: colors.onFaint)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: PTextStyles.of(context)
                        .editFieldValue
                        .copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Enter a student id',
                      hintStyle: TextStyle(
                          fontFamily: PFonts.ui, color: colors.onFaint),
                      isDense: true,
                      filled: true,
                      fillColor: colors.surface2,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.primary),
                      ),
                    ),
                    onSubmitted: (_) => _saveStudent(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _saveStudent,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('Set',
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: cs.onPrimary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text('ROSTER',
                style: PTextStyles.of(context)
                    .sectionLabel
                    .copyWith(color: colors.onFaint)),
            const SizedBox(height: 10),
            if (_studentId != null)
              GestureDetector(
                onTap: () => _openStudent(_studentId!),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.tealBg,
                      child: Icon(Icons.person, color: colors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_studentId!,
                          style: TextStyle(
                              fontFamily: PFonts.ui,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: cs.onSurface)),
                    ),
                    Icon(Icons.chevron_right, color: colors.onFaint),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
