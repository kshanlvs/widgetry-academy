import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';

/// Registration, saved exactly like the website's registration form. Required before payment.
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.courseId});
  final String courseId;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AuthCubit>().state.user?.displayName ?? '');
  final _phone = TextEditingController();
  String? _level;
  String _experience = RegistrationOptions.experience.first;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit(Course course) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final email = context.read<AuthCubit>().state.user?.email ?? '';
    final ok = await context.read<CoursesCubit>().register(Registration(name: _name.text, email: email, phone: _phone.text, level: _level ?? '', experience: _experience, course: course.title));
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<CoursesCubit, CoursesState>(
        listenWhen: (a, b) => b.error != null || b.message != null,
        listener: (context, s) => showMessage(context, s.error ?? s.message!),
        builder: (context, s) {
          final course = s.byId(widget.courseId);
          return Scaffold(
            appBar: AppBar(title: const Text('Reserve your seat')),
            body: course == null
                ? const SizedBox.shrink()
                : Form(
                    key: _form,
                    child: ListView(padding: const EdgeInsets.all(18), children: [
                      Text(course.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Register first, then pay to confirm your seat. We use your number only to send batch details on WhatsApp.'),
                      const SizedBox(height: 18),
                      TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => Validators.required(v, 'Name')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp number', prefixText: '+91 '), validator: Validators.indianMobile),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _level,
                        decoration: const InputDecoration(labelText: 'Class / course'),
                        items: [for (final l in RegistrationOptions.levels) DropdownMenuItem(value: l, child: Text(l))],
                        onChanged: (v) => setState(() => _level = v),
                        validator: (v) => v == null ? 'Please choose one' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _experience,
                        decoration: const InputDecoration(labelText: 'Coding experience'),
                        items: [for (final e in RegistrationOptions.experience) DropdownMenuItem(value: e, child: Text(e))],
                        onChanged: (v) => setState(() => _experience = v ?? _experience),
                      ),
                    ]),
                  ),
            bottomNavigationBar: course == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton(
                        onPressed: s.submitting ? null : () => _submit(course),
                        child: s.submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Register & continue'),
                      ),
                    ),
                  ),
          );
        },
      );
}
