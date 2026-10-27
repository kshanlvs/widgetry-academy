import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:widgetry_academy/features/profile/presentation/widgets/photo_picker.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';

/// Create or edit the profile the resume is built from.
/// [guest]: before signing in. The resume is kept on the phone and previewed; signing in saves it.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, this.guest = false});
  final bool guest;
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
  final _achievements = TextEditingController();
  final _languages = TextEditingController();

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
  /// Opted in to the Talent Network (recruiters can find the profile). Off: the profile only builds the resume.
  bool _network = false;
  bool _existing = false;
  bool _importing = false;
  /// What the last import filled in, shown on the import card.
  List<String>? _found;
  bool _foundByAi = false;
  /// The last file imported, kept so "Let AI read it" can send it again.
  PlatformFile? _lastFile;
  /// After the first Save, fields re-check as you type, so fixed errors disappear straight away.
  bool _submitted = false;
  /// Photo chosen before the profile exists; uploaded right after it's created.
  Uint8List? _pendingPhoto;
  JobsMeta _meta = JobsMeta.fallback;
  /// How the resume looks (kept with a guest draft).
  ResumeSettings _look = const ResumeSettings();

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileCubit>().state.profile;
    final user = context.read<AuthCubit>().state.user;
    if (p != null) {
      _existing = true;
      _network = p.talentNetwork;
      _fill(p);
      _hidden.text = p.hiddenCompanies ?? '';
      _salary.text = p.expectedSalaryLpa?.toString() ?? '';
      _jobTypes = [...p.jobTypes];
      _modes = [...p.workModes];
      _notice = p.noticePeriod;
      _openToWork = p.openToWork;
    } else if (context.read<ProfileCubit>().draft case final ProfileDraft d) {
      // A resume started before (on this phone): carry on from it
      final p = d.profile;
      _look = d.look;
      _network = p.talentNetwork;
      _fill(p);
      _hidden.text = p.hiddenCompanies ?? '';
      _salary.text = p.expectedSalaryLpa?.toString() ?? '';
      _jobTypes = [...p.jobTypes];
      _modes = [...p.workModes];
      _notice = p.noticePeriod;
      _openToWork = p.openToWork;
      if (_edu.isEmpty) _edu.add(_Row(['', '', '', '']));
    } else {
      _name.text = user?.displayName ?? '';
      _edu.add(_Row(['', '', '', '']));
      _apps.add(_Row(['', '', '', '']));
    }
    getIt<GetJobsMeta>()(const NoParams()).then((r) {
      if (mounted && r.valueOrNull != null) setState(() => _meta = r.valueOrNull!);
    });
  }

  /// Puts a profile into the form. With [onlyFound], blank values in [p] keep what's typed.
  void _fill(Candidate p, {bool onlyFound = false}) {
    void text(TextEditingController c, String? v) {
      if (!onlyFound || (v ?? '').trim().isNotEmpty) c.text = v ?? '';
    }

    void rows(List<_Row> list, List<_Row> next) {
      if (onlyFound && next.isEmpty) return;
      for (final r in list) {
        WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
      }
      list
        ..clear()
        ..addAll(next);
    }

    text(_name, p.fullName);
    text(_phone, p.phone);
    text(_headline, p.headline);
    if (!onlyFound || p.experienceYears > 0) _years.text = p.experienceYears == p.experienceYears.roundToDouble() ? p.experienceYears.toInt().toString() : p.experienceYears.toString();
    text(_company, p.currentCompany);
    text(_city, p.city);
    text(_about, p.about);
    text(_github, p.githubUrl);
    text(_linkedin, p.linkedinUrl);
    text(_portfolio, p.portfolioUrl);
    text(_achievements, p.achievements.join('\n'));
    text(_languages, p.languages.join(', '));
    if (p.categories.isNotEmpty) _cats = [...p.categories];
    if (!onlyFound || p.skills.isNotEmpty) _skills = [...p.skills.take(15)];
    rows(_work, [for (final w in p.experience) _Row([w.company, w.role, w.start, w.end ?? '', w.points ?? ''])..current = w.end == null]);
    rows(_edu, [for (final e in p.education) _Row([e.degree, e.institute, e.year?.toString() ?? '', e.score ?? ''])]);
    rows(_apps, [for (final a in p.apps) _Row([a.name, a.url ?? '', a.role ?? '', a.about ?? ''])]);
    rows(_certs, [for (final c in p.certifications) _Row([c.name, c.issuer ?? '', c.year?.toString() ?? ''])]);
  }

  /// Fills the form from an existing resume (PDF or Word). [ai]: let AI read the same file again.
  Future<void> _import({bool ai = false}) async {
    var file = ai ? _lastFile : null;
    if (file == null) {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'docx'], withData: true);
      file = picked?.files.firstOrNull;
    }
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      showMessage(context, 'Couldn\'t open that file. Try another one.');
      return;
    }
    if (_existing && !ai && !await _confirmReplace()) return;
    setState(() => _importing = true);
    final r = await getIt<ImportResume>()(ImportParams(bytes, fileName: file.name, ai: ai));
    if (!mounted) return;
    setState(() => _importing = false);
    r.fold((f) => showMessage(context, f.message), (res) {
      final p = res.profile;
      if (p == null) {
        showMessage(context, res.message ?? 'We couldn\'t read any text in that file. If it\'s a scanned image, fill the form instead.');
        return;
      }
      _lastFile = file;
      setState(() {
        _fill(p, onlyFound: true);
        _found = res.found;
        _foundByAi = res.ai;
        if (_edu.isEmpty) _edu.add(_Row(['', '', '', '']));
      });
      tick();
    });
  }

  Future<bool> _confirmReplace() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fill from your resume?'),
          content: const Text('What we find in the file replaces those parts of your profile. Nothing is saved until you tap Save.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fill it in'))],
        ),
      ) ==
      true;

  @override
  void dispose() {
    for (final c in [_achievements, _languages, _name, _phone, _headline, _years, _company, _city, _about, _github, _linkedin, _portfolio, _salary, _hidden, _skillInput]) {
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

  static String? _url(String text) {
    final n = Validators.normalizeUrl(text);
    return n.isEmpty ? null : n;
  }

  /// A row with anything typed in it must be complete (the server rejects half-filled rows).
  String? Function(String?) _neededIfRow(_Row r, String label) => (v) => r.c.any((c) => c.text.trim().isNotEmpty) && (v ?? '').trim().isEmpty ? '$label is required' : null;

  String? _endAfterStart(_Row r, String? v) {
    final e = _monthValidator(v, optional: true);
    if (e != null || (v ?? '').trim().isEmpty) return e;
    return v!.trim().compareTo(r.v(2)) < 0 ? 'Must be after the start date' : null;
  }

  /// Scrolls to the first field showing an error.
  void _showFirstError() {
    FormFieldState<dynamic>? first;
    void visit(Element e) {
      if (first != null) return;
      if (e is StatefulElement && e.state is FormFieldState && (e.state as FormFieldState).hasError) {
        first = e.state as FormFieldState;
        return;
      }
      e.visitChildren(visit);
    }

    _form.currentContext?.visitChildElements(visit);
    final ctx = first?.context;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.2, curve: Curves.easeOut);
  }

  Future<void> _pickPhoto() async {
    final cubit = context.read<ProfileCubit>();
    final hasPhoto = _pendingPhoto != null || cubit.state.profile?.photo != null;
    final bytes = await pickProfilePhoto(
      context,
      canRemove: hasPhoto,
      onRemove: () {
        if (_existing) {
          cubit.removePhoto();
        } else {
          setState(() => _pendingPhoto = null);
        }
      },
    );
    if (bytes == null || !mounted) return;
    if (_existing) {
      await cubit.uploadPhoto(bytes);
    } else {
      setState(() => _pendingPhoto = bytes);
    }
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
      githubUrl: _url(_github.text),
      linkedinUrl: _url(_linkedin.text),
      portfolioUrl: _url(_portfolio.text),
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
          if (r.v(0).isNotEmpty) AppItem(name: r.v(0), url: _url(r.v(1)), role: r.v(2).isEmpty ? null : r.v(2), about: r.v(3).isEmpty ? null : r.v(3)),
      ],
      certifications: [
        for (final r in _certs)
          if (r.v(0).isNotEmpty) CertItem(name: r.v(0), issuer: r.v(1).isEmpty ? null : r.v(1), year: int.tryParse(r.v(2))),
      ],
      achievements: [for (final l in _achievements.text.split('\n')) if (l.replaceFirst(RegExp(r'^\s*[-•*·]\s*'), '').trim().isNotEmpty) l.replaceFirst(RegExp(r'^\s*[-•*·]\s*'), '').trim()].take(10).toList(),
      languages: {for (final l in _languages.text.split(RegExp(r'[,\n]'))) if (l.trim().isNotEmpty) l.trim()}.take(10).toList(),
      talentNetwork: _network,
      photo: p?.photo,
      resumeSettings: p?.resumeSettings ?? const ResumeSettings(),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_submitted) setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) {
      showMessage(context, 'Please fix the highlighted fields.');
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstError());
      return;
    }
    if (_skills.isEmpty) {
      showMessage(context, 'Add at least one skill.');
      return;
    }
    final cubit = context.read<ProfileCubit>();
    if (widget.guest) {
      await cubit.keepDraft(ProfileDraft(_build(), look: _look));
      if (!mounted) return;
      final look = await context.push<ResumeSettings>('/resume/preview');
      if (look != null) _look = look;
      return;
    }
    final ok = await cubit.save(_build());
    if (!ok) return;
    final photo = _pendingPhoto;
    if (photo != null) await cubit.uploadPhoto(photo);
    if (!mounted) return;
    // A new profile goes straight to the resume it just made
    if (_existing) {
      context.pop();
    } else {
      context.pushReplacement('/profile/resume');
    }
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

  Widget _section(String title, List<Widget> children, {String? hint}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, Space.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall),
            if (hint != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint, style: t.bodySmall)),
          ]),
        ),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xs), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children))),
      ]),
    );
  }

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
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        decoration: BoxDecoration(color: Palette.of(context).bg, borderRadius: BorderRadius.circular(Radii.md)),
        child: Column(children: [...fields, Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onRemove, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Remove')))]),
      );

  @override
  Widget build(BuildContext context) {
    final saving = context.select<ProfileCubit, bool>((c) => c.state.saving);
    final savedPhoto = context.select<ProfileCubit, String?>((c) => c.state.profile?.photo);
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => b.error != null,
      listener: (context, s) => showMessage(context, s.error!),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.guest ? 'Build your resume' : _existing ? 'Edit profile' : 'Create profile'), titleSpacing: 0),
        body: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          // A Column (not a lazy ListView) keeps every field mounted, so Save checks all of them
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxxl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ImportCard(
              busy: _importing,
              existing: _existing,
              found: _found,
              byAi: _foundByAi,
              onImport: () => _import(),
              onAi: _lastFile == null || _foundByAi ? null : () => _import(ai: true),
            ),
            if (!widget.guest) _PhotoSection(
              name: _name.text,
              photo: _pendingPhoto != null ? 'data:image/jpeg;base64,${base64Encode(_pendingPhoto!)}' : savedPhoto,
              busy: saving,
              onTap: _pickPhoto,
            ),
            _section('I work with', [
              _chips({for (final c in _meta.categories) c.slug: c.name}, _cats, (v) => _cats = v),
            ], hint: 'Pick all that apply. We use this to match jobs and suggest skills.'),
            _section('About you', [
              _field(_name, 'Full name', validator: (v) => Validators.required(v, 'Name')),
              _field(_phone, 'Phone / WhatsApp (private)', keyboard: TextInputType.phone, hint: '+91 98765 43210', validator: Validators.optionalPhone),
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
                    Expanded(child: r.current ? const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Present')) : _field(r.c[3], 'To (YYYY-MM)', hint: '2024-12', validator: (v) => _endAfterStart(r, v))),
                  ]),
                  CheckboxListTile(value: r.current, onChanged: (v) => setState(() => r.current = v ?? false), title: const Text('I work here now'), contentPadding: EdgeInsets.zero, dense: true, controlAffinity: ListTileControlAffinity.leading),
                  _field(r.c[4], 'What you did (one point per line)', hint: 'Built live order tracking with Google Maps\nCut crash rate by 40%', maxLines: 5, maxLength: 1500),
                ], () => _removeRow(_work, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _work.add(_Row(['', '', '', '', '']))), icon: const Icon(Icons.add), label: const Text('Add a job')),
            ], hint: 'Newest first. Freshers can skip this and add projects.'),
            _section('Apps & projects', [
              for (final r in _apps)
                _rowCard(r, [
                  _field(r.c[0], 'App or project name', validator: _neededIfRow(r, 'Name')),
                  _field(r.c[1], 'Play Store / App Store / GitHub link', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
                  _field(r.c[2], 'Your role'),
                  _field(r.c[3], 'One line: what it does and the tech', maxLength: 400),
                ], () => _removeRow(_apps, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _apps.add(_Row(['', '', '', '']))), icon: const Icon(Icons.add), label: const Text('Add an app')),
            ], hint: 'A published app or GitHub link is the strongest proof you can ship.'),
            _section('Education', [
              for (final r in _edu)
                _rowCard(r, [
                  _field(r.c[0], 'Degree / course', hint: 'MCA, B.Tech CSE, Class 12', validator: _neededIfRow(r, 'Degree or course')),
                  _field(r.c[1], 'College / school', validator: _neededIfRow(r, 'College or school')),
                  Row(children: [
                    Expanded(child: _field(r.c[2], 'Year', keyboard: TextInputType.number, validator: Validators.optionalYear)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(r.c[3], 'Score (optional)', hint: '8.1 CGPA')),
                  ]),
                ], () => _removeRow(_edu, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _edu.add(_Row(['', '', '', '']))), icon: const Icon(Icons.add), label: const Text('Add education')),
            ]),
            _section('Certifications (optional)', [
              for (final r in _certs)
                _rowCard(r, [
                  _field(r.c[0], 'Certificate', hint: 'Flutter in 10 Days', validator: _neededIfRow(r, 'Certificate name')),
                  _field(r.c[1], 'Issued by', hint: 'Widgetry Academy'),
                  _field(r.c[2], 'Year', keyboard: TextInputType.number, validator: Validators.optionalYear),
                ], () => _removeRow(_certs, r)),
              OutlinedButton.icon(onPressed: () => setState(() => _certs.add(_Row(['', '', '']))), icon: const Icon(Icons.add), label: const Text('Add a certificate')),
            ]),
            _section('Achievements (optional)', [
              _field(_achievements, 'One per line', hint: 'Winner, Smart India Hackathon 2024\n1,000+ downloads on my first app', maxLines: 5, maxLength: 1500),
            ], hint: 'Awards, hackathons, ranks, open-source work.'),
            _section('Languages (optional)', [
              _field(_languages, 'Languages you speak', hint: 'English, Hindi, Telugu'),
            ]),
            _section('Links', [
              _field(_github, 'GitHub', hint: 'github.com/you', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
              _field(_linkedin, 'LinkedIn', hint: 'linkedin.com/in/you', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
              _field(_portfolio, 'Portfolio', hint: 'yoursite.com', keyboard: TextInputType.url, validator: Validators.optionalHttpsUrl),
            ]),
            _section('Widgetry Talent Network', [
              SwitchListTile(
                value: _network,
                onChanged: (v) => setState(() => _network = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Let mobile employers find me'),
                subtitle: const Text('Free. We review your profile and share it with employers only with your approval. Turn it off any time.'),
              ),
              if (_network) ...[
                const SizedBox(height: Space.sm),
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
                SwitchListTile(value: _openToWork, onChanged: (v) => setState(() => _openToWork = v), title: const Text("I'm open to work"), contentPadding: EdgeInsets.zero),
                _field(_hidden, 'Never show my profile to (comma separated)', hint: 'e.g. your current employer'),
              ],
              if (_existing) TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_forever_outlined), label: const Text('Delete my profile')),
            ], hint: 'Optional. Your resume works either way.'),
          ]),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: saving ? null : _save,
            child: BusyLabel(busy: saving, label: widget.guest ? 'Preview my resume' : _existing ? 'Save changes' : 'Save and see my resume'),
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

/// Profile photo at the top of the form. Optional; most recruiters don't need one.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.name, required this.photo, required this.busy, required this.onTap});
  final String name;
  final String? photo;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Card(
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: busy ? 0.5 : 1, child: Avatar(name: name.isEmpty ? '?' : name, photo: photo, size: 64)),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.line)),
                    child: Icon(Icons.photo_camera_outlined, size: 14, color: p.ink),
                  ),
                ),
              ]),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(photo == null ? 'Add a profile photo' : 'Profile photo', style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(photo == null ? 'Optional. A clear, friendly photo of your face.' : 'Tap to change or remove it.', style: t.bodySmall),
                ]),
              ),
              Text(photo == null ? 'Add' : 'Change', style: t.labelLarge?.copyWith(color: p.accent)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Import your resume" at the top: fills the form from a PDF or Word file.
class _ImportCard extends StatelessWidget {
  const _ImportCard({required this.busy, required this.existing, required this.found, required this.byAi, required this.onImport, this.onAi});
  final bool busy;
  final bool existing;
  final List<String>? found;
  final bool byAi;
  final VoidCallback onImport;
  final VoidCallback? onAi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final done = found != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: p.accent.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(done ? Icons.check_circle : Icons.upload_file, color: done ? AppColors.ok : p.accent),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                done ? (byAi ? 'AI filled in your details' : 'We filled in your details') : (existing ? 'Update from your resume' : 'Have a resume already? Skip the typing'),
                style: t.titleSmall,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            done
                ? (found!.isEmpty ? 'Check each section below and fill any gaps.' : 'Found ${found!.join(', ')}. Check each section below before saving.')
                : 'Upload a PDF or Word file and we fill the form for you. You can edit everything after.',
            style: t.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (busy)
              const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: Space.md), Text('Reading your resume…')])
            else ...[
              if (done)
                OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.description_outlined, size: 18), label: const Text('Use another file'))
              else
                FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.description_outlined, size: 18), label: const Text('Import PDF or Word')),
              if (done && onAi != null) FilledButton.tonal(onPressed: onAi, child: const Text('✨ Not right? Let AI read it')),
            ],
          ]),
        ]),
      ),
    );
  }
}
