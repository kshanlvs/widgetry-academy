import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/usecases/profile_usecases.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';

/// Live PDF preview of the resume with template, colour and section options. Share or print from here.
class ResumePage extends StatelessWidget {
  const ResumePage({super.key});

  static const templates = {'modern': 'Modern', 'classic': 'Classic', 'compact': 'Compact'};
  static const accents = {
    'green': Color(0xFF0F6B56),
    'navy': Color(0xFF1D3557),
    'black': Color(0xFF111111),
    'maroon': Color(0xFF7A1F2B),
    'teal': Color(0xFF0E6D7A),
    'purple': Color(0xFF53389E),
  };
  static const toggles = {'photo': 'Photo', 'phone': 'Phone', 'email': 'Email', 'city': 'City', 'summary': 'Summary', 'projects': 'Projects', 'education': 'Education', 'certifications': 'Certifications'};

  @override
  Widget build(BuildContext context) => BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, s) {
          final p = s.profile;
          if (p == null) return Scaffold(appBar: AppBar(title: const Text('Resume')), body: const ErrorView(message: 'Create your profile first.'));
          final rs = p.resumeSettings;
          return Scaffold(
            appBar: AppBar(
              title: const Text('My resume'),
              actions: [IconButton(tooltip: 'Customize', icon: const Icon(Icons.tune), onPressed: () => _customize(context, p))],
            ),
            body: PdfPreview(
              key: ValueKey(rs),
              build: (_) => getIt<BuildResumePdf>()(p, rs),
              pdfFileName: '${p.fullName.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim().replaceAll(' ', '-')}-Resume.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              loadingWidget: const LoadingView(message: 'Building your resume…'),
              onError: (context, e) => const ErrorView(message: 'Could not build the PDF. Check your connection (fonts download once) and try again.'),
            ),
          );
        },
      );

  void _customize(BuildContext context, Candidate p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(value: context.read<ProfileCubit>(), child: _CustomizeSheet(initial: p.resumeSettings, hasPhoto: p.photo != null, headline: p.headline)),
    );
  }
}

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet({required this.initial, required this.hasPhoto, required this.headline});
  final ResumeSettings initial;
  final bool hasPhoto;
  final String headline;
  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late ResumeSettings s = widget.initial;
  late final _title = TextEditingController(text: widget.initial.title ?? '');

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _set(ResumeSettings next) => setState(() => s = next);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Customize resume', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text('Template', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final e in ResumePage.templates.entries) ChoiceChip(label: Text(e.value), selected: s.template == e.key, onSelected: (_) => _set(s.copyWith(template: e.key))),
          ]),
          const SizedBox(height: 16),
          Text(s.template == 'classic' ? 'Colour (not used by Classic)' : 'Colour', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: [
            for (final e in ResumePage.accents.entries)
              GestureDetector(
                onTap: () => _set(s.copyWith(accent: e.key)),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: e.value, shape: BoxShape.circle, border: Border.all(color: s.accent == e.key ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3)),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _title, maxLength: 140, decoration: InputDecoration(labelText: 'Target job title', hintText: widget.headline)),
          Text('Show on resume', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in ResumePage.toggles.entries)
              FilterChip(
                label: Text(e.value),
                selected: e.key == 'photo' ? (s.showPhoto && widget.hasPhoto) : s.shows(e.key),
                onSelected: e.key == 'photo' && !widget.hasPhoto
                    ? null
                    : (on) => _set(e.key == 'photo'
                        ? s.copyWith(showPhoto: on)
                        : s.copyWith(hide: on ? s.hide.where((x) => x != e.key).toList() : [...s.hide, e.key])),
              ),
          ]),
          const SizedBox(height: 8),
          Text(widget.hasPhoto ? 'Most Indian IT companies and ATS software don\'t need a photo. Leave it off unless asked.' : 'Add a profile photo to use it on your resume.', style: t.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.read<ProfileCubit>().saveResumeSettings(s.copyWith(title: _title.text.trim()));
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ),
        ]),
      ),
    );
  }
}
