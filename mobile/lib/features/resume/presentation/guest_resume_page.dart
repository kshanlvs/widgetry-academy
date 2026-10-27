import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:printing/printing.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';

// Before signing in (like the website): the resume is kept on the phone, previewed by the server
// (nothing stored there) and scored. Signing in saves it to the account and unlocks downloads.

class GuestResumeState extends Equatable {
  const GuestResumeState({this.draft, this.pdf, this.building = false, this.pdfError, this.ats});
  final ProfileDraft? draft;
  final ResumeFile? pdf;
  final bool building;
  final String? pdfError;
  final AtsResult? ats;

  ResumeSettings get look => draft?.look ?? const ResumeSettings();

  GuestResumeState copyWith({ProfileDraft? draft, ResumeFile? pdf, bool? building, String? pdfError, AtsResult? ats}) =>
      GuestResumeState(draft: draft ?? this.draft, pdf: pdf ?? this.pdf, building: building ?? this.building, pdfError: pdfError, ats: ats ?? this.ats);

  @override
  List<Object?> get props => [draft?.profile, draft?.look, pdf, building, pdfError, ats];
}

@injectable
class GuestResumeCubit extends Cubit<GuestResumeState> {
  GuestResumeCubit(this._repo, this._profile) : super(const GuestResumeState());
  final ResumeRepository _repo;
  final ProfileCubit _profile;
  Timer? _debounce;
  int _n = 0;

  void start() {
    final d = _profile.draft;
    if (d == null) {
      emit(state.copyWith(pdfError: 'Nothing to preview yet. Fill in your details first.'));
      return;
    }
    emit(state.copyWith(draft: d));
    _build();
    _score();
  }

  Future<void> _build() async {
    final d = state.draft;
    if (d == null) return;
    final n = ++_n;
    emit(state.copyWith(building: true));
    final r = await _repo.guestPdf(d.profile, d.look);
    if (isClosed || n != _n) return;
    r.fold((f) => emit(state.copyWith(building: false, pdfError: f.message)), (f) => emit(state.copyWith(building: false, pdf: f)));
  }

  Future<void> _score() async {
    final d = state.draft;
    if (d == null) return;
    final r = await _repo.guestAts(d.profile);
    if (!isClosed && r.valueOrNull != null) emit(state.copyWith(ats: r.valueOrNull));
  }

  Future<void> retry() => _build();

  void setLook(ResumeSettings look) {
    final d = state.draft;
    if (d == null) return;
    final next = ProfileDraft(d.profile, look: look);
    emit(state.copyWith(draft: next));
    _profile.keepDraft(next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _build);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

class GuestResumePage extends StatelessWidget {
  const GuestResumePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => getIt<GuestResumeCubit>()..start(), child: const _GuestView());
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GuestResumeCubit>().state;
    final cubit = context.read<GuestResumeCubit>();
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    final pdf = s.pdf;
    final look = s.look;
    return PopScope(
      canPop: false,
      // Back to the form, which keeps the chosen look
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(look);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Your resume'), titleSpacing: 0),
        body: Column(children: [
          if (s.ats != null) _AtsStrip(ats: s.ats!),
          SizedBox(
            height: 52,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm), children: [
              for (final e in resumeTemplates.entries)
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: ChoiceChip(
                    label: Text(proTemplates.contains(e.key) ? '${e.value} · PRO' : e.value),
                    selected: look.template == e.key,
                    onSelected: (_) {
                      tick();
                      cubit.setLook(look.copyWith(template: e.key));
                      if (proTemplates.contains(e.key)) showMessage(context, '${e.value} is a Premium template, so the preview has a watermark.');
                    },
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.sm, 0),
            child: Row(children: [
              Expanded(
                child: Text(
                  pdf == null ? '' : '${pdf.pages} page${pdf.pages > 1 ? 's' : ''}${pdf.pages == 1 ? ' · fits on one page ✓' : ''}',
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (pdf != null && pdf.pages >= 2 && look.density != 'tight')
                TextButton.icon(
                  onPressed: () => cubit.setLook(look.copyWith(density: look.density == 'compact' ? 'tight' : 'compact')),
                  icon: const Icon(Icons.compress, size: 18),
                  label: const Text('Fit to one page'),
                ),
            ]),
          ),
          if (s.building) LinearProgressIndicator(minHeight: 2, color: p.accent) else const SizedBox(height: 2),
          Expanded(
            child: pdf == null
                ? (s.pdfError != null ? ErrorView(message: s.pdfError!, onRetry: cubit.retry) : const LoadingView(message: 'Making your resume…'))
                : PdfPreview(
                    key: ValueKey(pdf.bytes.hashCode),
                    build: (_) async => pdf.bytes,
                    useActions: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    maxPageWidth: 720,
                    padding: const EdgeInsets.all(Space.md),
                    scrollViewDecoration: BoxDecoration(color: p.bg),
                    loadingWidget: const LoadingView(message: 'Making your resume…'),
                  ),
          ),
        ]),
        bottomNavigationBar: BottomActionBar(
          leading: OutlinedButton(onPressed: () => context.pop(look), child: const Text('Edit')),
          child: FilledButton.icon(
            onPressed: () => context.push('/sign-in?from=${Uri.encodeComponent('/profile/resume')}'),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Save & download'),
          ),
        ),
      ),
    );
  }
}

/// ATS score at the top; tap for what to improve.
class _AtsStrip extends StatelessWidget {
  const _AtsStrip({required this.ats});
  final AtsResult ats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final c = ats.score >= 85 ? AppColors.ok : ats.score >= 70 ? AppColors.green : ats.score >= 50 ? AppColors.warn : AppColors.bad;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Material(
        color: c.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: c.withValues(alpha: 0.25))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _details(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: ats.score / 100, strokeWidth: 4, color: c, backgroundColor: c.withValues(alpha: 0.15))),
                  Text('${ats.score}', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Text('ATS score: ${ats.grade}', style: t.titleSmall)),
              Text('How to improve', style: t.labelLarge?.copyWith(color: p.accent)),
              Icon(Icons.chevron_right_rounded, color: p.accent),
            ]),
          ),
        ),
      ),
    );
  }

  void _details(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) {
          final t = Theme.of(ctx).textTheme;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.92,
            builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl), children: [
              Text('ATS score ${ats.score}/100 · ${ats.grade}', style: t.titleMedium),
              const SizedBox(height: Space.md),
              for (final cat in ats.categories) ...[
                Row(children: [Expanded(child: Text(cat.label, style: t.titleSmall)), Text('${cat.score}/${cat.max}', style: t.labelLarge)]),
                const SizedBox(height: 4),
                Text(cat.detail, style: t.bodySmall),
                for (final tip in cat.tips) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $tip', style: t.bodySmall)),
                const SizedBox(height: Space.md),
              ],
              if (ats.missing.isNotEmpty) ...[
                Text('Keywords recruiters look for', style: t.titleSmall),
                const SizedBox(height: Space.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final k in ats.missing.take(15)) Pill(text: k, color: AppColors.warn)]),
                const SizedBox(height: Space.md),
              ],
              Text('Sign in (free) to save it, download PDF and Word, and check it against any job.', style: t.bodySmall),
            ]),
          );
        },
      );
}
