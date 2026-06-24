import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';

/// Combined sign-in / sign-up screen — a mode toggle rather than two pages,
/// since the form fields are identical and the only difference is which
/// AuthCubit method the submit button calls.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;
    final cubit = context.read<AuthCubit>();
    if (_isSignUp) {
      cubit.signUp(email: email, password: password);
    } else {
      cubit.signIn(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.traineeSurface,
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            final errorMessage =
                state is AuthUnauthenticated ? state.errorMessage : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text('Pahlevani', style: HomeText.gaegu(size: 30)),
                  const SizedBox(height: 4),
                  Text(_isSignUp ? 'Create your account' : 'Welcome back',
                      style: HomeText.caveat(size: 20)),
                  const SizedBox(height: 28),
                  _Field(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _Field(
                      label: 'Password',
                      controller: _passwordCtrl,
                      obscureText: true),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(errorMessage,
                        style: HomeText.patrickHand(
                            size: 13, color: HomeColors.orangeTextDeep)),
                  ],
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: isLoading ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HomeColors.orange,
                        borderRadius: HomeRadii.button,
                        border: homeBorder(),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isSignUp ? 'Sign up' : 'Sign in',
                              style: HomeText.gaegu(
                                  size: 17, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () => context.read<AuthCubit>().signInWithGoogle(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HomeColors.card,
                        borderRadius: HomeRadii.button,
                        border: homeBorder(),
                      ),
                      child: Text('Continue with Google',
                          style: HomeText.patrickHand(size: 15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                        style:
                            HomeText.caveat(size: 17, color: HomeColors.teal),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HomeText.mono(size: 11)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: HomeColors.card,
            borderRadius: HomeRadii.tile,
            border: homeBorder(),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: HomeText.patrickHand(size: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
