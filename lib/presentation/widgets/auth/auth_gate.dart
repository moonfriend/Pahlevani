import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/auth_page.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';

/// Wraps the authenticated app: shows [AuthPage] when signed out,
/// [PrivacyConsentPage] when signed in but not yet consented (covers both
/// email and Google sign-in — Google has no in-form opportunity for a
/// consent checkbox), and [child] once both are satisfied.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthInitial() || AuthLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          AuthUnauthenticated() => const AuthPage(),
          AuthAuthenticated(user: final user) when !user.hasConsented =>
            const PrivacyConsentPage(),
          AuthAuthenticated() => widget.child,
        };
      },
    );
  }
}
