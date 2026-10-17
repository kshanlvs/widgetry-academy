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
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.surface,
      appBar: AppBar(backgroundColor: p.surface),
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (a, b) => b.error != null || b.info != null,
        listener: (context, s) => showMessage(context, s.error ?? s.info!),
        builder: (context, s) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page + 4, 0, Space.page + 4, Space.xxxl),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 40)),
              const SizedBox(height: Space.xl),
              Text(_creating ? 'Create your account' : 'Sign in to Widgetry', style: t.headlineSmall),
              const SizedBox(height: 6),
              Text('One account for the app and widgetryacademy.in. Your saved jobs, profile and course seat stay in sync.', style: t.bodyMedium?.copyWith(color: p.muted)),
              const SizedBox(height: Space.xxl),
              OutlinedButton(
                onPressed: s.busy ? null : () async => _done(await context.read<AuthCubit>().signInWithGoogle()),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [GoogleLogo(size: 19), SizedBox(width: 12), Text('Continue with Google')]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xl),
                child: Row(children: [
                  Expanded(child: Divider(color: p.line)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or with email', style: t.bodySmall?.copyWith(color: p.faint))),
                  Expanded(child: Divider(color: p.line)),
                ]),
              ),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(children: [
                    if (_creating) ...[
                      TextFormField(controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => Validators.required(v, 'Name')),
                      const SizedBox(height: Space.md),
                    ],
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email'), validator: Validators.email),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: _creating ? 'At least 8 characters' : null,
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: _creating ? Validators.password : (v) => Validators.required(v, 'Password'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ]),
                ),
              ),
              if (!_creating) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: s.busy ? null : _forgot, child: const Text('Forgot password?'))) else const SizedBox(height: Space.lg),
              const SizedBox(height: Space.xs),
              FilledButton(onPressed: s.busy ? null : _submit, child: BusyLabel(busy: s.busy, label: _creating ? 'Create account' : 'Sign in')),
              const SizedBox(height: Space.md),
              Center(
                child: TextButton(
                  onPressed: s.busy ? null : () => setState(() => _creating = !_creating),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: _creating ? 'Already have an account? ' : 'New to Widgetry? ', style: TextStyle(color: p.muted, fontWeight: FontWeight.w500)),
                    TextSpan(text: _creating ? 'Sign in' : 'Create an account'),
                  ])),
                ),
              ),
              const SizedBox(height: Space.xl),
              Text(
                'By continuing you agree to the Terms and Privacy Policy at ${AppConfig.siteUrl.replaceFirst('https://', '')}.',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: p.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The multicolour Google "G", drawn so no image asset is needed.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GPainter());
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke);
    Paint pen(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.1415926535 / 180;
    // Clockwise from 3 o'clock; the opening of the G is the upper-right quarter.
    canvas.drawArc(rect, 0, 45 * deg, false, pen(const Color(0xFF4285F4))); // blue
    canvas.drawArc(rect, 45 * deg, 90 * deg, false, pen(const Color(0xFF34A853))); // green
    canvas.drawArc(rect, 135 * deg, 90 * deg, false, pen(const Color(0xFFFBBC05))); // yellow
    canvas.drawArc(rect, 225 * deg, 90 * deg, false, pen(const Color(0xFFEA4335))); // red
    canvas.drawRect(Rect.fromLTWH(w * 0.52, (w - stroke) / 2, w * 0.48, stroke), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
