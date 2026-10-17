import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';

/// Create or edit the Talent Network profile (the resume is built from it).
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _Row {
  _Row(List<String> values) : c = [for (final v in values) TextEditingController(text: v)];
  final List<TextEditingController> c;
  bool current = false;
  String v(int i) => c[i].text.trim();
  void dispose() {
    for (final x in c) {
      x.dispose();
    }
  }
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _headline = TextEditingController();
  final _years = TextEditingController(text: '0');
  final _company = TextEditingController();
  final _city = TextEditingController();
  final _about = TextEditingController();
  final _github = TextEditingController();
  final _linkedin = TextEditingController();
  final _portfolio = TextEditingController();
  final _salary = TextEditingController();
  final _hidden = TextEditingController();
  final _skillInput = TextEditingController();

  final List<_Row> _work = [];
  final List<_Row> _edu = [];
  final List<_Row> _apps = [];
  final List<_Row> _certs = [];

  List<String> _cats = ['flutter'];
  List<String> _skills = ['Flutter', 'Dart'];
  List<String> _jobTypes = [];
  List<String> _modes = [];
  String? _notice;
  bool _openToWork = true;
  bool _consent = false;
  bool _existing = false;
  JobsMeta _meta = JobsMeta.fallback;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileCubit>().state.profile;
    final user = context.read<AuthCubit>().state.user;
    if (p != null) {
      _existing = true;
      _consent = true;
      _name.text = p.fullName;
      _phone.text = p.phone ?? '';
      _headline.text = p.headline;
      _years.text = p.experienceYears == p.experienceYears.roundToDouble() ? p.experienceYears.toInt().toString() : p.experienceYears.toString();
      _company.text = p.currentCompany ?? '';
      _city.text = p.city ?? '';
      _about.text = p.about ?? '';
      _github.text = p.githubUrl ?? '';
      _linkedin.text = p.linkedinUrl ?? '';
      _portfolio.text = p.portfolioUrl ?? '';
      _salary.text = p.expectedSalaryLpa?.toString() ?? '';
      _hidden.text = p.hiddenCompanies ?? '';
      _cats = [...p.categories];
      _skills = [...p.skills];
      _jobTypes = [...p.jobTypes];
      _modes = [...p.workModes];
      _notice = p.noticePeriod;
      _openToWork = p.openToWork;
      for (final w in p.experience) {
        _work.add(_Row([w.company, w.role, w.start, w.end ?? '', w.points ?? ''])..current = w.end == null);
      }
      for (final e in p.education) {
        _edu.add(_Row([e.degree, e.institute, e.year?.toString() ?? '', e.score ?? '']));
      }
      for (final a in p.apps) {
        _apps.add(_Row([a.name, a.url ?? '', a.role ?? '', a.about ?? '']));
      }
      for (final c in p.certifications) {
        _certs.add(_Row([c.name, c.issuer ?? '', c.year?.toString() ?? '']));
      }
    } else {
      _name.text = user?.displayName ?? '';
      _edu.add(_Row(['', '', '', '']));
      _apps.add(_Row(['', '', '', '']));
    }
    getIt<GetJobsMeta>()(const NoParams()).then((r) {
      if (mounted && r.valueOrNull != null) setState(() => _meta = r.valueOrNull!);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _headline, _years, _company, _city, _about, _github, _linkedin, _portfolio, _salary, _hidden, _skillInput]) {
      c.dispose();
    }
    for (final r in [..._work, ..._edu, ..._apps, ..._certs]) {
      r.dispose();
    }
    super.dispose();
  }

  List<String> get _suggested {
    final picked = _meta.categories.where((c) => _cats.contains(c.slug)).expand((c) => c.suggestedSkills).toList();
    return {...(picked.isEmpty ? const ['Flutter', 'Dart', 'Firebase', 'Bloc', 'Provider', 'Riverpod', 'REST APIs', 'Clean Architecture', 'Testing', 'Git'] : picked), ..._skills}.toList();
  }

  String? _monthValidator(String? v, {bool optional = false}) {
    if ((v ?? '').trim().isEmpty) return optional ? null : 'Required';
    return RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(v!.trim()) ? null : 'Use YYYY-MM';
  }

  Candidate _build() {
    final p = context.read<ProfileCubit>().state.profile;
    return Candidate(
      fullName: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      headline: _headline.text.trim(),
      experienceYears: ((double.tryParse(_years.text.trim()) ?? 0) * 2).round() / 2,
      currentCompany: _company.text.trim().isEmpty ? null : _company.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      about: _about.text.trim().isEmpty ? null : _about.text.trim(),
      githubUrl: _github.text.trim().isEmpty ? null : _github.text.trim(),
      linkedinUrl: _linkedin.text.trim().isEmpty ? null : _linkedin.text.trim(),
      portfolioUrl: _portfolio.text.trim().isEmpty ? null : _portfolio.text.trim(),
      expectedSalaryLpa: double.tryParse(_salary.text.trim()),
      hiddenCompanies: _hidden.text.trim().isEmpty ? null : _hidden.text.trim(),
      categories: _cats.isEmpty ? const ['flutter'] : _cats,
      skills: _skills,
      jobTypes: _jobTypes,
      workModes: _modes,
      noticePeriod: _notice,
      openToWork: _openToWork,
      experience: [
        for (final r in _work)
          if (r.v(0).isNotEmpty || r.v(1).isNotEmpty) WorkItem(company: r.v(0), role: r.v(1), start: r.v(2), end: r.current || r.v(3).isEmpty ? null : r.v(3), points: r.v(4).isEmpty ? null : r.v(4)),
      ],
      education: [
        for (final r in _edu)
          if (r.v(0).isNotEmpty || r.v(1).isNotEmpty) EduItem(degree: r.v(0), institute: r.v(1), year: int.tryParse(r.v(2)), score: r.v(3).isEmpty ? null : r.v(3)),
      ],
      apps: [
        for (final r in _apps)
          if (r.v(0).isNotEmpty) AppItem(name: r.v(0), url: r.v(1).isEmpty ? null : r.v(1), role: r.v(2).isEmpty ? null : r.v(2), about: r.v(3).isEmpty ? null : r.v(3)),
      ],
      certifications: [
        for (final r in _certs)
          if (r.v(0).isNotEmpty) CertItem(name: r.v(0), issuer: r.v(1).isEmpty ? null : r.v(1), year: int.tryParse(r.v(2))),
      ],
      photo: p?.photo,
      resumeSettings: p?.resumeSettings ?? const ResumeSettings(),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      showMessage(context, 'Please fix the highlighted fields.');
      return;
    }
    if (_skills.isEmpty) {
      showMessage(context, 'Add at least one skill.');
      return;
    }
    if (!_consent) {
      showMessage(context, 'Please tick the consent box at the bottom.');
      return;
    }
    final ok = await context.read<ProfileCubit>().save(_build());
    if (ok && mounted) context.pop();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your profile?'),
        content: const Text('This removes your Talent Network profile, photo and resume settings. It can\'t be undone.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
      ),
    );
    if (yes != true || !mounted) return;
    if (await context.read<ProfileCubit>().deleteProfile() && mounted) context.pop();
  }

  // ---------- small builders ----------
  Widget _field(TextEditingController c, String label, {String? hint, String? Function(String?)? validator, TextInputType? keyboard, int maxLines = 1, int? maxLength}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(controller: c, decoration: InputDecoration(labelText: label, hintText: hint), validator: validator, keyboardType: keyboard, maxLines: maxLines, minLines: 1, maxLength: maxLength),
      );

  Widget _section(String title, List<Widget> children, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (hint != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint, style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(height: 12),
              ...children,
            ]),
          ),
        ),
      );

  Widget _chips(Map<String, String> options, List<String> selected, void Function(List<String>) onChange) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in options.entries)
          FilterChip(
            label: Text(e.value),
            selected: selected.contains(e.key),
            onSelected: (on) => setState(() => onChange(on ? [...selected, e.key] : selected.where((x) => x != e.key).toList())),
          ),
      ]);

  Widget _rowCard(_Row r, List<Widget> fields, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [...fields, Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onRemove, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Remove')))]),
      );

  @override
  Widget build(BuildContext context) {
    final saving = context.select<ProfileCubit, bool>((c) => c.state.saving);
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => b.error != null,
      listener: (context, s) => showMessage(context, s.error!),
      child: Scaffold(
        appBar: AppBar(title: Text(_existing ? 'Edit profile' : 'Create profile')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
            _section('I work with', [
              _chips({for (final c in _meta.categories) c.slug: c.name}, _cats, (v) => _cats = v),
            ], hint: 'Pick all that apply. We use this to match jobs and suggest skills.'),
            _section('About you', [
              _field(_name, 'Full name', validator: (v) => Validators.required(v, 'Name')),
              _field(_phone, 'Phone / WhatsApp (private)', keyboard: TextInputType.phone, hint: '+91 98765 43210'),
              _field(_headline, 'Headline', hint: 'e.g. Flutter Developer · 3 years · Bloc & Firebase', validator: (v) => (v ?? '').trim().length < 4 ? 'Add a short headline' : null, maxLength: 140),
              Row(children: [
                Expanded(child: _field(_years, 'Experience (years)', keyboard: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (double.tryParse((v ?? '').trim()) ?? -1) < 0 ? 'Enter a number' : null)),
                const SizedBox(width: 12),
                Expanded(child: _field(_city, 'City')),
              ]),
              _field(_company, 'Current company (optional)'),
              _field(_about, 'About (optional)', hint: 'What have you built? What are you looking for next?', maxLines: 5, maxLength: 2000),
            ]),
            _section('Skills', [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _suggested)
                  FilterChip(
                    label: Text(s),
                    selected: _skills.contains(s),
                    onSelected: (on) => setState(() => _skills = on ? (_skills.length < 15 ? [..._skills, s] : _skills) : _skills.where((x) => x != s).toList()),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _skillInput, decoration: const InputDecoration(hintText: 'Add another skill'), onSubmitted: (_) => _addSkill())),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: _addSkill, icon: const Icon(Icons.add)),
              ]),
            ], hint: 'Up to 15.'),
            _section('Work experience', [
              for (final r in _work)
                _rowCard(r, [
                  _field(r.c[0], 'Company', validator: (v) => Validators.required(v, 'Company')),
                  _field(r.c[1], 'Role', validator: (v) => Validators.required(v, 'Role')),
                  Row(children: [
                    Expanded(child: _field(r.c[2], 'From (YYYY-MM)', hint: '2023-06', validator: _monthValidator)),
                    const SizedBox(width: 12),
                    Expanded(child: r.current ? const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Present')) : _field(r.c[3], 'To (YYYY-MM)', hint: '2024-12', validator: (v) => _monthValidator(v, optional: true))),
                  ]),
                  CheckboxListTile(value: r.current, onChanged: (v) => setState(() => r.current = v ?? false), title: const Text('I work here now'), contentPadding: EdgeInsets.zero, dense: true, controlAffinity: ListTileControlAffinity.leading),
                  _field(r.c[4], 'What you did (one point per line)', hint: 'Built live order tracking with Google Maps\nCut crash rate by 40%', maxLines: 5, maxLength: 1500),
                ], () => _removeRow(_work, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _work.add(_Row(['', '', '', '', '']))), icon: const Icon(Icons.add), label: const Text('Add a job')),
            ], hint: 'Newest first. Freshers can skip this and add projects.'),
            _section('Apps & projects', [
              for (final r in _apps)
                _rowCard(r, [
                  _field(r.c[0], 'App or project name'),
                  _field(r.c[1], 'Play Store / App Store / GitHub link', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
                  _field(r.c[2], 'Your role'),
                  _field(r.c[3], 'One line: what it does and the tech', maxLength: 400),
                ], () => _removeRow(_apps, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _apps.add(_Row(['', '', '', '']))), icon: const Icon(Icons.add), label: const Text('Add an app')),
            ], hint: 'A published app or GitHub link is the strongest proof you can ship.'),
            _section('Education', [
              for (final r in _edu)
                _rowCard(r, [
                  _field(r.c[0], 'Degree / course', hint: 'MCA, B.Tech CSE, Class 12'),
                  _field(r.c[1], 'College / school'),
                  Row(children: [
                    Expanded(child: _field(r.c[2], 'Year', keyboard: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(r.c[3], 'Score (optional)', hint: '8.1 CGPA')),
                  ]),
                ], () => _removeRow(_edu, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _edu.add(_Row(['', '', '', '']))), icon: const Icon(Icons.add), label: const Text('Add education')),
            ]),
            _section('Certifications (optional)', [
              for (final r in _certs)
                _rowCard(r, [
                  _field(r.c[0], 'Certificate', hint: 'Flutter in 10 Days'),
                  _field(r.c[1], 'Issued by', hint: 'Widgetry Academy'),
                  _field(r.c[2], 'Year', keyboard: TextInputType.number),
                ], () => _removeRow(_certs, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _certs.add(_Row(['', '', '']))), icon: const Icon(Icons.add), label: const Text('Add a certificate')),
            ]),
            _section('Links', [
              _field(_github, 'GitHub', hint: 'https://github.com/you', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
              _field(_linkedin, 'LinkedIn', hint: 'https://linkedin.com/in/you', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
              _field(_portfolio, 'Portfolio', hint: 'https://', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
            ]),
            _section('What you\'re looking for', [
              const Text('Job type'),
              const SizedBox(height: 6),
              _chips(Labels.jobType, _jobTypes, (v) => _jobTypes = v),
              const SizedBox(height: 14),
              const Text('Work mode'),
              const SizedBox(height: 6),
              _chips(Labels.workMode, _modes, (v) => _modes = v),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _notice,
                decoration: const InputDecoration(labelText: 'Notice period'),
                items: [for (final e in Labels.notice.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _notice = v),
              ),
              const SizedBox(height: 12),
              _field(_salary, 'Expected salary in LPA (private)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ]),
            _section('Privacy', [
              SwitchListTile(value: _openToWork, onChanged: (v) => setState(() => _openToWork = v), title: const Text("I'm open to work"), contentPadding: EdgeInsets.zero),
              _field(_hidden, 'Never show my profile to (comma separated)', hint: 'e.g. your current employer'),
              CheckboxListTile(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I agree that Widgetry may review my profile and share it with mobile employers only with my approval. I can delete it any time.'),
              ),
              if (_existing) TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_forever_outlined), label: const Text('Delete my profile')),
            ]),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: saving ? null : _save,
              child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(_existing ? 'Save changes' : 'Create my profile'),
            ),
          ),
        ),
      ),
    );
  }

  void _removeRow(List<_Row> list, _Row r) {
    setState(() => list.remove(r));
    WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
  }

  void _addSkill() {
    final v = _skillInput.text.trim();
    if (v.isNotEmpty && _skills.length < 15 && !_skills.any((s) => s.toLowerCase() == v.toLowerCase())) setState(() => _skills = [..._skills, v]);
    _skillInput.clear();
  }
}
