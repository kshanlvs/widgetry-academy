import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/widgets/common.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';
import 'package:widgetry_academy/features/resume/presentation/resume_cubit.dart';
import 'package:widgetry_academy/features/resume/presentation/resume_panels.dart';

/// My resume: the real PDF (same 6 templates as the website), ATS score, AI writer, design and saved copies.
class ResumePage extends StatelessWidget {
  const ResumePage({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<ProfileCubit, ProfileStatus>((c) => c.state.status);
    final hasDraft = context.select<ProfileCubit, bool>((c) => c.state.draft != null && c.state.profile != null);
    if (status == ProfileStatus.loading) return Scaffold(appBar: AppBar(title: const Text('My resume')), body: const LoadingView(message: 'Loading your resume…'));
    if (context.read<ProfileCubit>().state.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My resume')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xxl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.description_outlined, size: 48),
              const SizedBox(height: Space.md),
              Text('Build your resume in 2 minutes', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: Space.sm),
              const Text('Import the resume you already have (PDF or Word) and we fill everything in.', textAlign: TextAlign.center),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () => context.push('/profile/edit'), child: const Text('Build my resume')),
            ]),
          ),
        ),
      );
    }
    if (hasDraft) return const _DraftChoice();
    return BlocProvider(create: (_) => getIt<ResumeCubit>()..start(), child: const _ResumeView());
  }
}

/// Signed in to an account that already had a resume, with a new one made before signing in.
class _DraftChoice extends StatelessWidget {
  const _DraftChoice();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    final s = context.watch<ProfileCubit>().state;
    final t = Theme.of(context).textTheme;
    final draft = s.draft!.profile;
    final saved = s.profile!;
    Widget option(String label, Candidate c) => Card(
          child: ListTile(
            title: Text(label, style: t.labelLarge),
            subtitle: Text([c.fullName, c.headline, '${c.experience.length} job${c.experience.length == 1 ? '' : 's'} · ${c.skills.length} skills'].join('\n')),
            isThreeLine: true,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('My resume')),
      body: ListView(padding: const EdgeInsets.all(Space.page), children: [
        Text('You already have a resume', style: t.headlineSmall),
        const SizedBox(height: Space.sm),
        Text('Which one should your account keep? The other is deleted.', style: t.bodyMedium),
        const SizedBox(height: Space.lg),
        option('Just made on this phone', draft),
        option('Saved in your account', saved),
      ]),
      bottomNavigationBar: BottomActionBar(
        leading: OutlinedButton(onPressed: s.saving ? null : cubit.discardDraft, child: const Text('Keep saved')),
        child: FilledButton(onPressed: s.saving ? null : cubit.useDraft, child: BusyLabel(busy: s.saving, label: 'Use the new one')),
      ),
    );
  }
}

class _ResumeView extends StatelessWidget {
  const _ResumeView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ResumeCubit, ResumeState>(
      listenWhen: (a, b) => b.message != null || b.error != null,
      listener: (context, s) => showMessage(context, s.error ?? s.message!),
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const _VersionTitle(),
            titleSpacing: 0,
            actions: [
              IconButton(
                tooltip: 'Edit details',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final cubit = context.read<ResumeCubit>();
                  await context.push('/profile/edit');
                  cubit.refreshPreview();
                },
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [Tab(text: 'Preview'), Tab(text: 'ATS score'), Tab(text: '✨ AI writer'), Tab(text: 'Design')],
            ),
          ),
          body: const TabBarView(children: [PreviewTab(), AtsTab(), AiTab(), DesignTab()]),
          bottomNavigationBar: const _DownloadBar(),
        ),
      ),
    );
  }
}

/// "My resume" or the name of the saved copy on screen, with a menu to switch.
class _VersionTitle extends StatelessWidget {
  const _VersionTitle();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final t = Theme.of(context).textTheme;
    if (s.versions.isEmpty) return const Text('My resume');
    return PopupMenuButton<int>(
      tooltip: 'Switch resume',
      onSelected: (id) => context.read<ResumeCubit>().openVersion(id < 0 ? null : id),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: -1, checked: s.versionId == null, child: const Text('Main resume')),
        const PopupMenuDivider(),
        for (final v in s.versions) CheckedPopupMenuItem(value: v.id, checked: s.versionId == v.id, child: Text(v.name, overflow: TextOverflow.ellipsis)),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(s.version?.name ?? 'My resume', overflow: TextOverflow.ellipsis, style: t.titleLarge)),
        const Icon(Icons.arrow_drop_down),
      ]),
    );
  }
}

/// Word and PDF downloads, always one tap away.
class _DownloadBar extends StatefulWidget {
  const _DownloadBar();
  @override
  State<_DownloadBar> createState() => _DownloadBarState();
}

class _DownloadBarState extends State<_DownloadBar> {
  bool _pdf = false, _word = false;

  Future<void> _download({required bool word}) async {
    final cubit = context.read<ResumeCubit>();
    // A Pro template without Premium, or Word (Premium only)
    if (cubit.state.locked || (word && !cubit.state.premium.active)) return showUpsell(context);
    setState(() => word ? _word = true : _pdf = true);
    final f = await cubit.download(word: word);
    if (mounted) setState(() => word ? _word = false : _pdf = false);
    if (f == null) return;
    if (word) {
      await Share.shareXFiles([XFile.fromData(f.bytes, name: f.fileName, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')], subject: f.fileName);
    } else {
      await Printing.sharePdf(bytes: f.bytes, filename: f.fileName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.select<ResumeCubit, bool>((c) => c.state.locked);
    final pro = context.select<ResumeCubit, bool>((c) => c.state.premium.active);
    return BottomActionBar(
      leading: OutlinedButton(onPressed: _word ? null : () => _download(word: true), child: BusyLabel(busy: _word, label: pro ? 'Word' : '🔒 Word')),
      child: FilledButton.icon(
        onPressed: _pdf ? null : () => _download(word: false),
        icon: Icon(locked ? Icons.lock_outline : Icons.download_rounded, size: 18),
        label: BusyLabel(busy: _pdf, label: locked ? 'Unlock to download' : 'Download PDF'),
      ),
    );
  }
}

// ---------- Preview ----------
class PreviewTab extends StatelessWidget {
  const PreviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final cubit = context.read<ResumeCubit>();
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    final pdf = s.pdf;
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm), children: [
          for (final e in resumeTemplates.entries)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.value),
                  if (proTemplates.contains(e.key)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
                      child: Text(s.premium.active ? 'PRO' : '🔒 PRO', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.goldInk)),
                    ),
                  ],
                ]),
                selected: s.look.template == e.key,
                onSelected: (_) {
                  tick();
                  cubit.setLook(s.look.copyWith(template: e.key));
                  if (!s.premium.canUse(e.key)) showMessage(context, '${e.value} is a Premium template: the preview has a watermark.', actionLabel: 'Unlock', onAction: () => showUpsell(context));
                },
              ),
            ),
        ]),
      ),
      if (s.version != null)
        _Banner(
          icon: Icons.copy_all_outlined,
          text: 'Showing your copy "${s.version!.name}". Downloads and the ATS score use it.',
          action: 'Main resume',
          onAction: () => cubit.openVersion(null),
        ),
      if (s.locked)
        _Banner(icon: Icons.lock_outline, text: 'Premium template: the preview has a watermark. Get Premium to download it clean.', action: 'Unlock', onAction: () => showUpsell(context), warm: true),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.sm, 0),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: pdf == null ? '…' : '${pdf.pages} page${pdf.pages > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: pdf == null ? '' : pdf.pages == 1 ? ' · fits on one page ✓' : pdf.pages > 2 ? ' · recruiters prefer 1–2 pages' : ''),
            ]), style: t.bodySmall),
          ),
          if (pdf != null && pdf.pages == 2 && s.look.density != 'tight')
            TextButton.icon(
              onPressed: () => s.fullLook ? cubit.setLook(s.look.copyWith(density: s.look.density == 'compact' ? 'tight' : 'compact')) : showUpsell(context),
              icon: Icon(s.fullLook ? Icons.compress : Icons.lock_outline, size: 18),
              label: const Text('Fit to one page'),
            ),
        ]),
      ),
      if (s.building) LinearProgressIndicator(minHeight: 2, color: p.accent) else const SizedBox(height: 2),
      Expanded(
        child: pdf == null
            ? (s.pdfError != null ? ErrorView(message: s.pdfError!, onRetry: cubit.refreshPreview) : const LoadingView(message: 'Making your resume…'))
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
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.action, required this.onAction, this.warm = false});
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onAction;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = warm ? AppColors.warn : p.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Row(children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        TextButton(onPressed: onAction, child: Text(action)),
      ]),
    );
  }
}

// ---------- Design ----------
class DesignTab extends StatefulWidget {
  const DesignTab({super.key});
  @override
  State<DesignTab> createState() => _DesignTabState();
}

class _DesignTabState extends State<DesignTab> {
  late final TextEditingController _title = TextEditingController(text: context.read<ResumeCubit>().state.look.title ?? '');
  static const accents = {
    'green': Color(0xFF0F6B56), 'navy': Color(0xFF1D3557), 'black': Color(0xFF111111),
    'maroon': Color(0xFF7A1F2B), 'teal': Color(0xFF0E6D7A), 'purple': Color(0xFF53389E),
  };

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ResumeCubit>().state;
    final cubit = context.read<ResumeCubit>();
    final profile = context.select<ProfileCubit, Candidate?>((c) => c.state.profile);
    final t = Theme.of(context).textTheme;
    final look = s.look;
    final pro = s.fullLook;
    final hasPhoto = profile?.photo != null;
    return ListView(padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xxxl), children: [
      SectionCard(
        title: 'Design',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _title,
            maxLength: 140,
            decoration: InputDecoration(labelText: 'Target job title (under your name)', hintText: profile?.headline),
            onChanged: (v) => cubit.setLook(look.copyWith(title: v.trim())),
          ),
          _ProLabel(title: 'Fit to one page', locked: !pro),
          const SizedBox(height: 2),
          Text('The same resume, slightly smaller.', style: t.bodySmall),
          const SizedBox(height: Space.sm),
          Opacity(
            opacity: pro ? 1 : 0.5,
            child: SegmentedButton<String>(
              segments: [for (final e in resumeDensities.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {pro ? look.density : 'normal'},
              showSelectedIcon: false,
              onSelectionChanged: (v) => pro ? cubit.setLook(look.copyWith(density: v.first)) : showUpsell(context),
            ),
          ),
          const SizedBox(height: Space.lg),
          _ProLabel(title: look.template == 'classic' ? 'Colour (Classic uses it for the header line)' : 'Colour', locked: !pro),
          const SizedBox(height: Space.sm),
          Wrap(spacing: 12, children: [
            for (final e in accents.entries)
              Semantics(
                button: true,
                selected: look.accent == e.key,
                label: e.key,
                child: GestureDetector(
                  onTap: () => pro ? cubit.setLook(look.copyWith(accent: e.key)) : showUpsell(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: pro ? e.value : e.value.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: pro && look.accent == e.key ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: Space.lg),
          Text('Show on resume', style: t.titleSmall),
          const SizedBox(height: Space.sm),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in resumeParts.entries)
              FilterChip(
                label: Text(proParts.contains(e.key) && !pro ? '${e.value} 🔒' : e.value),
                selected: proParts.contains(e.key) && !pro ? false : e.key == 'photo' ? look.showPhoto && hasPhoto : look.shows(e.key),
                onSelected: e.key == 'photo' && !hasPhoto
                    ? null
                    : proParts.contains(e.key) && !pro
                        ? (_) => showUpsell(context)
                        : (on) => cubit.setLook(e.key == 'photo'
                            ? look.copyWith(showPhoto: on)
                            : look.copyWith(hide: on ? look.hide.where((x) => x != e.key).toList() : [...look.hide, e.key])),
              ),
          ]),
          const SizedBox(height: Space.sm),
          Text(hasPhoto ? "Most Indian IT companies and ATS don't need a photo. Leave it off unless asked." : 'Add a profile photo to use it on your resume.', style: t.bodySmall),
        ]),
      ),
      if (!s.premium.active) ...[
        const SizedBox(height: Space.lg),
        SectionCard(
          title: 'Classic and Modern are free',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clean and ATS-friendly, with a fixed colour and a small "Made with Widgetry" line at the bottom. Premium adds 6 more templates, Key highlights, colours, a photo, fit to one page and Word download.', style: t.bodySmall),
            const SizedBox(height: Space.sm),
            TextButton(onPressed: () => showUpsell(context), child: const Text('See Premium')),
          ]),
        ),
      ],
      const SizedBox(height: Space.lg),
      const CopiesCard(),
    ]);
  }
}

/// A Design setting's title, with a PRO tag when it needs Premium.
class _ProLabel extends StatelessWidget {
  const _ProLabel({required this.title, required this.locked});
  final String title;
  final bool locked;

  @override
  Widget build(BuildContext context) => Row(children: [
        Flexible(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        if (locked) ...[
          const SizedBox(width: Space.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
            child: const Text('🔒 PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.goldInk)),
          ),
        ],
      ]);
}
