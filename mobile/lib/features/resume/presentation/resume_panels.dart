import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';
import 'package:widgetry_academy/features/resume/presentation/resume_cubit.dart';

Color _statusColor(String s) => s == 'good' ? AppColors.ok : s == 'ok' ? AppColors.warn : AppColors.bad;
Color _scoreColor(int s) => s >= 85 ? AppColors.ok : s >= 70 ? AppColors.green : s >= 50 ? AppColors.warn : AppColors.bad;
String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

// ---------- ATS score ----------
class AtsTab extends StatelessWidget {
  const AtsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final r = s.ats;
    if (r == null) return s.atsLoading ? const LoadingView(message: 'Checking your resume…') : ErrorView(message: 'Couldn\'t check your resume.', onRetry: () => context.read<ResumeCubit>().setJob(s.job));
    final t = Theme.of(context).textTheme;
    final c = _scoreColor(r.score);
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xxxl), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: r.score / 100, strokeWidth: 8, color: c, backgroundColor: c.withValues(alpha: 0.12), strokeCap: StrokeCap.round)),
                  Text('${r.score}', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.grade, style: t.titleLarge?.copyWith(color: c, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(r.mode == 'job' ? 'ATS score out of 100, checked against the job below' : 'ATS score out of 100, checked against what recruiters expect for your role', style: t.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: Space.md),
        const _JobCard(),
        if (r.matched.isNotEmpty || r.missing.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          SectionCard(
            title: r.mode == 'job' ? 'Keywords from the job' : 'Keywords for your role',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.missing.isNotEmpty) ...[
                Text('Missing (${r.missing.length}): add the ones you really have${r.key.isNotEmpty ? '. ★ = key for this job' : ''}', style: t.bodySmall),
                const SizedBox(height: Space.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final k in r.missing) Pill(text: r.key.contains(k) ? '★ $k' : k, color: AppColors.warn)]),
                const SizedBox(height: Space.md),
              ],
              if (r.matched.isNotEmpty) ...[
                Text('On your resume (${r.matched.length})', style: t.bodySmall),
                const SizedBox(height: Space.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final k in r.matched) Pill(text: k, color: AppColors.ok)]),
              ],
              if (r.missing.isNotEmpty) ...[
                const SizedBox(height: Space.md),
                Wrap(spacing: 8, children: [
                  OutlinedButton(onPressed: () => context.push('/profile/edit'), child: const Text('Edit skills')),
                  if (s.job != null)
                    FilledButton.tonal(
                      onPressed: () {
                        DefaultTabController.of(context).animateTo(2);
                        if (s.premium.active) context.read<ResumeCubit>().runAi(AiAction.tailor);
                      },
                      child: const Text('✨ Tailor with AI'),
                    ),
                ]),
              ],
            ]),
          ),
        ],
        const SizedBox(height: Space.md),
        SectionCard(
          title: 'What the score is made of',
          child: Column(children: [
            for (final cat in r.categories)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(cat.label, style: t.titleSmall)),
                    Text('${cat.score}/${cat.max}', style: t.labelLarge?.copyWith(color: _statusColor(cat.status), fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: cat.max == 0 ? 0 : cat.score / cat.max, minHeight: 6, color: _statusColor(cat.status), backgroundColor: _statusColor(cat.status).withValues(alpha: 0.12)),
                  ),
                  const SizedBox(height: 6),
                  Text(cat.detail, style: t.bodySmall),
                  for (final tip in cat.tips) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $tip', style: t.bodySmall)),
                ]),
              ),
            Text('Every ATS scores a little differently; this check follows what most of them look for.', style: t.bodySmall),
          ]),
        ),
      ]),
      if (s.atsLoading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
    ]);
  }
}

/// The job the resume is checked against: paste one, or pick a Widgetry job.
class _JobCard extends StatelessWidget {
  const _JobCard();

  @override
  Widget build(BuildContext context) {
    final job = context.select<ResumeCubit, TargetJob?>((c) => c.state.job);
    final cubit = context.read<ResumeCubit>();
    final t = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Check against a job',
      child: job != null
          ? Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job.title, style: t.titleSmall),
                  if (job.company != null) Text(job.company!, style: t.bodySmall),
                ]),
              ),
              TextButton(onPressed: () => cubit.setJob(null), child: const Text('Remove')),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('See the keywords a job wants that your resume is missing.', style: t.bodySmall),
              const SizedBox(height: Space.md),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(onPressed: () => _pickJob(context), icon: const Icon(Icons.work_outline, size: 18), label: const Text('Pick a Widgetry job')),
                OutlinedButton.icon(onPressed: () => _pasteJob(context), icon: const Icon(Icons.content_paste, size: 18), label: const Text('Paste a job')),
              ]),
            ]),
    );
  }
}

Future<void> _pasteJob(BuildContext context) async {
  final cubit = context.read<ResumeCubit>();
  final c = TextEditingController();
  final text = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(Space.page, 0, Space.page, MediaQuery.of(ctx).viewInsets.bottom + Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Paste the job description', style: Theme.of(ctx).textTheme.titleMedium),
        const SizedBox(height: Space.md),
        TextField(controller: c, autofocus: true, minLines: 6, maxLines: 12, decoration: const InputDecoration(hintText: 'Paste the whole description, including the skills it asks for…')),
        const SizedBox(height: Space.md),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Check my resume')),
      ]),
    ),
  );
  c.dispose();
  if (text == null || text.isEmpty) return;
  if (text.length < 80) {
    if (context.mounted) showMessage(context, 'Paste the full job description (at least a few lines).');
    return;
  }
  final first = text.split('\n').firstWhere((l) => l.trim().length > 3, orElse: () => '').trim();
  await cubit.setJob(TargetJob(title: first.isNotEmpty && first.length <= 90 ? first : 'Pasted job description', text: text));
}

Future<void> _pickJob(BuildContext context) async {
  final cubit = context.read<ResumeCubit>();
  final cat = context.read<ProfileCubit>().state.profile?.categories.firstOrNull;
  final job = await showModalBottomSheet<Job>(context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true, builder: (_) => _JobPicker(category: cat));
  if (job == null) return;
  // The description is needed for the AI writer; the ATS check reads it on the server
  final full = (await getIt<GetJobDetail>()(job.id)).valueOrNull ?? job;
  await cubit.setJob(TargetJob(id: full.id, title: full.title, company: full.company.name, text: '${full.title}\n${full.description ?? ''}\nSkills: ${full.skills.join(', ')}'));
}

class _JobPicker extends StatefulWidget {
  const _JobPicker({this.category});
  final String? category;
  @override
  State<_JobPicker> createState() => _JobPickerState();
}

class _JobPickerState extends State<_JobPicker> {
  final _q = TextEditingController();
  List<Job>? _jobs;
  String? _error;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final n = ++_n;
    final q = _q.text.trim();
    final r = await getIt<SearchJobs>()(SearchJobsParams(JobFilter(query: q, category: q.isEmpty ? widget.category : null), pageSize: 15));
    if (!mounted || n != _n) return;
    setState(() => r.fold((f) => _error = f.message, (v) {
          _jobs = v.items;
          _error = null;
        }));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
          child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search jobs: Flutter, Android, iOS…'), onChanged: (_) => _search()),
        ),
        Expanded(
          child: _jobs == null
              ? (_error != null ? ErrorView(message: _error!, onRetry: _search) : const LoadingView())
              : _jobs!.isEmpty
                  ? const EmptyView(icon: Icons.work_off_outlined, title: 'No jobs found')
                  : ListView.separated(
                      itemCount: _jobs!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final j = _jobs![i];
                        return ListTile(
                          leading: CompanyLogo(name: j.company.name),
                          title: Text(j.title, style: t.titleSmall),
                          subtitle: Text([j.company.name, j.city ?? (j.mode == 'remote' ? 'Remote' : null)].whereType<String>().join(' · ')),
                          onTap: () => Navigator.pop(context, j),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ---------- AI writer ----------
class AiTab extends StatefulWidget {
  const AiTab({super.key});
  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  int _exp = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final cubit = context.read<ResumeCubit>();
    final profile = context.select<ProfileCubit, Candidate?>((c) => c.state.profile);
    final t = Theme.of(context).textTheme;
    final pr = s.premium;
    if (!pr.active) {
      return ListView(padding: const EdgeInsets.all(Space.lg), children: [
        const UpsellCard(),
        const SizedBox(height: Space.md),
        SectionCard(title: 'See it in action', child: Text('Pick a job in the ATS score tab to see your keyword gaps for free. Premium then rewrites your resume to close them.', style: t.bodySmall)),
      ]);
    }
    final jobs = profile?.experience ?? const <WorkItem>[];
    if (_exp >= jobs.length) _exp = 0;
    final needJob = Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: TextButton.icon(onPressed: () => DefaultTabController.of(context).animateTo(1), icon: const Icon(Icons.work_outline, size: 18), label: const Text('Pick a job in ATS score first')),
    );
    return ListView(padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xxxl), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Pill(text: '✨ PREMIUM', color: AppColors.warn),
              const SizedBox(width: Space.sm),
              Expanded(child: Text([if (pr.expiresAt != null) 'until ${_date(pr.expiresAt!)}', if (pr.aiLeftToday != null) '${pr.aiLeftToday} AI requests left today'].join(' · '), style: t.bodySmall)),
            ]),
            if (pr.endsSoon) ...[
              const SizedBox(height: Space.sm),
              Row(children: [
                Expanded(child: Text('Ends soon. Extend by ${pr.days} days for ₹${pr.price}; the days add on top.', style: t.bodySmall)),
                TextButton(onPressed: () => startPurchase(context), child: const Text('Extend')),
              ]),
            ],
            const SizedBox(height: Space.sm),
            Text('AI sees your resume text, not your phone or email. It never makes up numbers: it leaves [placeholders] for you to fill. Check every line before you use it.', style: t.bodySmall),
          ]),
        ),
      ),
      const SizedBox(height: Space.md),
      _AiCard(
        title: s.job == null ? 'Tailor to a job' : 'Tailor to ${s.job!.title}',
        hint: 'Rewrites your summary and most relevant points for this job, and finds skills to add.',
        action: AiAction.tailor,
        button: '✨ Tailor my resume',
        enabled: s.job != null,
        extra: s.job == null ? needJob : null,
      ),
      _AiCard(title: 'Professional summary', hint: 'A sharp 3–4 line summary${s.job != null ? ' aimed at this job' : ''}.', action: AiAction.summary, button: '✨ Write my summary'),
      _AiCard(
        title: 'Improve bullet points',
        hint: jobs.isEmpty ? 'Add work experience first.' : 'Rewrites one job\'s points into results recruiters notice.',
        action: AiAction.bullets,
        button: '✨ Rewrite these points',
        enabled: jobs.isNotEmpty,
        experienceIndex: _exp,
        extra: jobs.length > 1
            ? Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: DropdownButtonFormField<int>(
                  initialValue: _exp,
                  decoration: const InputDecoration(labelText: 'Job'),
                  items: [for (final (i, w) in jobs.indexed) DropdownMenuItem(value: i, child: Text('${w.role} · ${w.company}', overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => _exp = v ?? 0),
                ),
              )
            : null,
      ),
      _AiCard(
        title: 'Cover letter',
        hint: 'A short, specific letter for ${s.job?.company ?? 'the job you\'re applying to'}.',
        action: AiAction.cover,
        button: '✨ Write cover letter',
        enabled: s.job != null,
        extra: s.job == null ? needJob : null,
      ),
      if (s.versions.isEmpty) ...[
        const SizedBox(height: Space.sm),
        Text('Tip: after tailoring, save it as a copy for that job. Your main resume stays as it is.', style: t.bodySmall),
      ],
      const SizedBox(height: Space.sm),
      Center(child: TextButton(onPressed: () => cubit.refreshPreview(), child: const Text('Refresh preview'))),
    ]);
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.title, required this.hint, required this.action, required this.button, this.enabled = true, this.extra, this.experienceIndex});
  final String title;
  final String hint;
  final AiAction action;
  final String button;
  final bool enabled;
  final Widget? extra;
  final int? experienceIndex;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final cubit = context.read<ResumeCubit>();
    final t = Theme.of(context).textTheme;
    final busy = s.aiBusy == action;
    final res = s.ai[action];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: SectionCard(
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(hint, style: t.bodySmall),
          ?extra,
          const SizedBox(height: Space.md),
          if (busy)
            const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: Space.md), Text('Writing… this takes a few seconds.')])
          else if (res == null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(onPressed: enabled && s.aiBusy == null ? () => cubit.runAi(action, experienceIndex: experienceIndex) : null, child: Text(button)),
            )
          else
            _AiResultView(action: action, result: res),
        ]),
      ),
    );
  }
}

class _AiResultView extends StatelessWidget {
  const _AiResultView({required this.action, required this.result});
  final AiAction action;
  final AiResult result;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final cubit = context.read<ResumeCubit>();
    final profile = context.read<ProfileCubit>().state.profile;
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    Widget bullets(List<String> l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final x in l) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $x'))]);
    final target = s.version == null ? 'my main resume' : '"${s.version!.name}"';
    final copyText = switch (result) {
      SummaryResult(:final summary) => summary,
      BulletsResult(:final points) => points.map((x) => '• $x').join('\n'),
      TailorResult(:final summary) => summary,
      CoverResult(:final letter) => letter,
    };
    final Widget body = switch (result) {
      SummaryResult(:final summary) => Text(summary),
      BulletsResult(:final points, :final note) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bullets(points), if (note != null) Text(note, style: t.bodySmall)]),
      CoverResult(:final letter) => SelectableText(letter),
      TailorResult(:final summary, :final jobs, :final addSkills, :final gaps, :final tips) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Summary for this job', style: t.titleSmall),
          const SizedBox(height: 4),
          Text(summary),
          for (final e in jobs.entries) ...[
            const SizedBox(height: Space.md),
            Text([profile?.experience.elementAtOrNull(e.key)?.role, profile?.experience.elementAtOrNull(e.key)?.company].whereType<String>().join(' · '), style: t.titleSmall),
            const SizedBox(height: 4),
            bullets(e.value),
          ],
          if (addSkills.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text('Skills to add (your resume shows them)', style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final k in addSkills) Pill(text: k, color: AppColors.ok)]),
          ],
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text('Gaps (add only if true, or learn them)', style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final k in gaps) Pill(text: k, color: AppColors.warn)]),
          ],
          if (tips.isNotEmpty) ...[const SizedBox(height: Space.md), Text('Tips', style: t.titleSmall), const SizedBox(height: 4), bullets(tips)],
        ]),
    };
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: p.soft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        body,
        const SizedBox(height: Space.md),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (result is TailorResult && s.version == null)
            FilledButton(onPressed: () => _saveCopy(context), child: const Text('Save as a copy for this job')),
          if (result is TailorResult && s.version == null)
            OutlinedButton(onPressed: () => cubit.applyAi(action), child: Text('Apply to $target'))
          else if (result is! CoverResult)
            FilledButton(
              onPressed: () => cubit.applyAi(action),
              child: Text(result is TailorResult ? 'Apply to $target' : result is SummaryResult ? 'Use this summary' : 'Replace these points'),
            ),
          if (result is CoverResult)
            FilledButton.icon(onPressed: () => Share.share(copyText, subject: 'Cover letter'), icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Share')),
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyText));
              showMessage(context, 'Copied');
            },
            child: const Text('Copy'),
          ),
        ]),
        const SizedBox(height: 6),
        Text(result is CoverResult ? 'Replace [Your Name] and anything in brackets before you send it.' : 'Fill in any [placeholders] with your real numbers.', style: t.bodySmall),
      ]),
    );
  }

  Future<void> _saveCopy(BuildContext context) async {
    final cubit = context.read<ResumeCubit>();
    final job = cubit.state.job;
    final name = await askText(context, title: 'Name this copy', initial: (job?.company ?? job?.title ?? 'Copy'), button: 'Save copy');
    if (name != null && name.isNotEmpty) await cubit.saveAsCopy(name);
  }
}

Future<String?> askText(BuildContext context, {required String title, String initial = '', String button = 'Save'}) async {
  final c = TextEditingController(text: initial.length > 80 ? initial.substring(0, 80) : initial);
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, maxLength: 80, textCapitalization: TextCapitalization.sentences),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(button))],
    ),
  );
  c.dispose();
  return v;
}

// ---------- Saved copies ----------
class CopiesCard extends StatelessWidget {
  const CopiesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final cubit = context.read<ResumeCubit>();
    final t = Theme.of(context).textTheme;
    if (!s.premium.active && s.versions.isEmpty) {
      return SectionCard(
        title: 'A copy for each job',
        trailing: const Pill(text: '✨ PREMIUM', color: AppColors.warn),
        child: Text('Tailor your resume to a job and keep it as its own copy, so your main resume stays as it is. Up to ${s.premium.maxVersions} copies.', style: t.bodySmall),
      );
    }
    return SectionCard(
      title: 'Your resumes',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CopyRow(title: 'Main resume', open: s.versionId == null, onOpen: () => cubit.openVersion(null)),
        for (final v in s.versions)
          _CopyRow(
            title: v.name,
            subtitle: v.subtitle,
            open: s.versionId == v.id,
            onOpen: () => cubit.openVersion(v.id),
            onRename: () async {
              final name = await askText(context, title: 'Rename this copy', initial: v.name);
              if (name != null && name.isNotEmpty && name != v.name) await cubit.renameVersion(v.id, name);
            },
            onDelete: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete "${v.name}"?'),
                  content: const Text("Your main resume isn't affected."),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
                ),
              );
              if (yes == true) await cubit.deleteVersion(v.id);
            },
          ),
        const SizedBox(height: Space.sm),
        Text(
          s.premium.active
              ? 'Make a copy from ✨ AI writer → Tailor, then "Save as a copy for this job". ${s.versions.length}/${s.premium.maxVersions} used.'
              : 'Your copies stay yours. Renew Premium to make new ones or edit them.',
          style: t.bodySmall,
        ),
      ]),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.title, this.subtitle = '', required this.open, required this.onOpen, this.onRename, this.onDelete});
  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Space.sm),
      decoration: BoxDecoration(
        color: open ? p.accent.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: open ? p.accent : p.line),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onTap: open ? null : onOpen,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (open) Text('Showing', style: Theme.of(context).textTheme.bodySmall),
          if (onRename != null) IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onRename),
          if (onDelete != null) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
        ]),
      ),
    );
  }
}

// ---------- Resume Premium ----------
class UpsellCard extends StatelessWidget {
  const UpsellCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final pr = s.premium;
    const on = AppColors.deepMuted;
    Widget point(String b, String rest) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(children: [const TextSpan(text: '•  '), TextSpan(text: b, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)), TextSpan(text: rest)]), style: const TextStyle(color: on, height: 1.35)),
        );
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.deep, AppColors.deep2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(99)),
          child: const Text('✨ RESUME PREMIUM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.goldInk)),
        ),
        if (pr.ended) ...[
          const SizedBox(height: Space.md),
          Text('Your Premium ended on ${_date(pr.expiresAt!)}. Your resume is safe: free templates still download without a watermark.', style: const TextStyle(color: Color(0xFFFFD98A), fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: Space.md),
        const Text('Get shortlisted faster with AI', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: Space.md),
        point('Tailor your resume to any job', ' in one tap: summary, points and missing keywords'),
        point('Rewrite weak points', ' into results recruiters notice'),
        point('AI cover letter', ' for each application'),
        point('A saved copy for each job', ', your main resume stays as it is'),
        point('3 pro templates', ': Executive, Minimal and Elegant, without the watermark'),
        const SizedBox(height: Space.md),
        Row(children: [
          Text('₹${pr.price}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Expanded(child: Text('one-time · ${pr.days} days', style: const TextStyle(color: on))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.goldInk),
            onPressed: s.buying ? null : () => startPurchase(context),
            child: BusyLabel(busy: s.buying, label: pr.ended ? 'Renew' : 'Upgrade'),
          ),
        ]),
        const SizedBox(height: Space.sm),
        Text('No subscription, nothing renews automatically. ${pr.paymentsEnabled ? '' : 'Payments open soon.'}', style: const TextStyle(color: on, fontSize: 12.5)),
      ]),
    );
  }
}

/// The Premium card in a sheet (from a locked template or download).
Future<void> showUpsell(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(value: context.read<ResumeCubit>(), child: const Padding(padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl), child: UpsellCard())),
    );

/// Buys Premium. With Google's choice screen, asks for the state first (Google needs it for tax).
Future<void> startPurchase(BuildContext context) async {
  final cubit = context.read<ResumeCubit>();
  final pr = cubit.state.premium;
  String? state;
  if (BuyResumePremium.usesStore(pr, getIt<StoreBilling>())) {
    state = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm), child: Text('Which state are you in?', style: Theme.of(ctx).textTheme.titleMedium)),
          Expanded(
            child: ListView(children: [
              for (final s in pr.android?.states ?? const <String>[])
                ListTile(title: Text(_titleCase(s)), onTap: () => Navigator.pop(ctx, s)),
            ]),
          ),
        ]),
      ),
    );
    if (state == null) return;
  }
  // Opened from the Premium sheet: close it once Premium is on
  final route = context.mounted ? ModalRoute.of(context) : null;
  await cubit.buy(taxState: state);
  if (context.mounted && route is ModalBottomSheetRoute && route.isCurrent && cubit.state.premium.active) Navigator.of(context).pop();
}

/// "WEST BENGAL" → "West Bengal", "DADRA AND NAGAR HAVELI" → "Dadra and Nagar Haveli"
String _titleCase(String s) => s.split(' ').where((w) => w.isNotEmpty).map((w) => w == 'AND' ? 'and' : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');
