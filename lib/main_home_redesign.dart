import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/home/trainee_home_page.dart';
import 'package:pahlevani/presentation/pages/home/trainer_home_page.dart';
import 'package:pahlevani/presentation/widgets/auth/auth_gate.dart';

/// Entry point for the home redesign with real auth wired in front of it —
/// separate from main_home_preview.dart (which stays auth-free, mock-data
/// only) and from lib/main.dart (the shipped app; untouched by this epic).
/// Run with:
///   flutter run -t lib/main_home_redesign.dart -d linux
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await DependencyInjection().ensureInitialized();
  runApp(const _HomeRedesignApp());
}

class _HomeRedesignApp extends StatelessWidget {
  const _HomeRedesignApp();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: getIt<AuthCubit>(),
      child: const MaterialApp(
        title: 'Pahlevani',
        debugShowCheckedModeBanner: false,
        home: AuthGate(child: _RoleSwitcher()),
      ),
    );
  }
}

/// Routes to Trainee Home or Trainer Page by the signed-in user's role —
/// with a manual override button so both screens stay reviewable without
/// needing a real trainer account set up yet.
class _RoleSwitcher extends StatefulWidget {
  const _RoleSwitcher();

  @override
  State<_RoleSwitcher> createState() => _RoleSwitcherState();
}

class _RoleSwitcherState extends State<_RoleSwitcher> {
  bool? _showTrainerOverride;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final isTrainer = state is AuthAuthenticated ? state.user.isTrainer : false;
    final showTrainer = _showTrainerOverride ?? isTrainer;

    return Scaffold(
      appBar: AppBar(
        title: Text(showTrainer ? 'Trainer Page' : 'Trainee Home'),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => _showTrainerOverride = !showTrainer),
            child: Text(showTrainer ? 'View Trainee' : 'View Trainer',
                style: const TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            child:
                const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: showTrainer ? const TrainerHomePage() : const TraineeHomePage(),
    );
  }
}
