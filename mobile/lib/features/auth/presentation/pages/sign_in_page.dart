import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';

/// Google or email sign-in. Same account as widgetryacademy.in.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.redirectTo});
  final String? redirectTo;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _done(bool ok) {
    if (!ok || !mounted) return;
    final to = widget.redirectTo;
    if (to != null && to.startsWith('/')) {
      context.go(to);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final c = context.read<AuthCubit>();
    _done(_creating ? await c.signUp(_name.text, _email.text, _password.text) : await c.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _forgot() async {
    if (Validators.email(_email.text) != null) {
      showMessage(context, 'Enter your email above first.');
      return;
    }
    await context.read<AuthCubit>().resetPassword(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (a, b) => b.error != null || b.info != null,
        listener: (context, s) => showMessage(context, s.error ?? s.info!),
        builder: (context, s) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            children: [
              Text(_creating ? 'Create your account' : 'Welcome back', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Use the same account as widgetryacademy.in. Your jobs, profile and course registration stay in sync.', style: t.bodyMedium),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: s.busy ? null : () async => _done(await context.read<AuthCubit>().signInWithGoogle()),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: const Text('Continue with Google'),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or')), Expanded(child: Divider())])),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(children: [
                    if (_creating) ...[
                      TextFormField(controller: _name, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => Validators.required(v, 'Name')),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email'), validator: Validators.email),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showPassword = !_showPassword)),
                      ),
                      validator: _creating ? Validators.password : (v) => Validators.required(v, 'Password'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ]),
                ),
              ),
              if (!_creating) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: s.busy ? null : _forgot, child: const Text('Forgot password?'))),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: s.busy ? null : _submit,
                child: s.busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(_creating ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: s.busy ? null : () => setState(() => _creating = !_creating),
                child: Text(_creating ? 'Already have an account? Sign in' : 'New here? Create an account'),
              ),
              const SizedBox(height: 18),
              Text(
                'By continuing you agree to our terms and privacy policy (${AppConfig.siteUrl.replaceFirst('https://', '')}).',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
