import 'package:flutter/material.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Trainer · Students')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student ID',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter a student id',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveStudent(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveStudent,
                  child: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Roster', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_studentId != null)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(_studentId!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openStudent(_studentId!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
