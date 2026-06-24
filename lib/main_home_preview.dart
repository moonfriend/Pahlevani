import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/pages/home/trainee_home_page.dart';
import 'package:pahlevani/presentation/pages/home/trainer_home_page.dart';

/// Standalone entry point for reviewing the home redesign (Track 1) without
/// touching the production app. Run with:
///   flutter run -t lib/main_home_preview.dart -d linux
void main() {
  runApp(const _HomePreviewApp());
}

class _HomePreviewApp extends StatelessWidget {
  const _HomePreviewApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pahlevani Home Redesign Preview',
      debugShowCheckedModeBanner: false,
      home: _PreviewSwitcher(),
    );
  }
}

class _PreviewSwitcher extends StatefulWidget {
  const _PreviewSwitcher();

  @override
  State<_PreviewSwitcher> createState() => _PreviewSwitcherState();
}

class _PreviewSwitcherState extends State<_PreviewSwitcher> {
  bool _showTrainer = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showTrainer ? 'Trainer Page' : 'Trainee Home'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showTrainer = !_showTrainer),
            child: Text(
              _showTrainer ? 'View Trainee' : 'View Trainer',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _showTrainer ? const TrainerHomePage() : const TraineeHomePage(),
    );
  }
}
