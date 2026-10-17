import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/di/injection.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/core/widgets/state_views.dart';
import 'package:widgetry_academy/features/blog/domain/blog.dart';

class BlogState extends Equatable {
  const BlogState({this.loading = true, this.posts = const [], this.error});
  final bool loading;
  final List<BlogPost> posts;
  final String? error;
  @override
  List<Object?> get props => [loading, posts, error];
}

@injectable
class BlogCubit extends Cubit<BlogState> {
  BlogCubit(this._get, this._links) : super(const BlogState());
  final GetBlogPosts _get;
  final LinkLauncher _links;

  Future<void> load() async {
    final r = await _get(const NoParams());
    emit(r.fold((f) => BlogState(loading: false, posts: state.posts, error: f.message), (p) => BlogState(loading: false, posts: p)));
  }

  Future<void> open(BlogPost p) => _links.openInApp(p.url);
}

/// Career guides from widgetryacademy.in/blog. New posts appear automatically.
class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<BlogCubit>()..load(),
        child: Scaffold(
          body: BlocBuilder<BlogCubit, BlogState>(
            builder: (context, s) {
              final cubit = context.read<BlogCubit>();
              final t = Theme.of(context).textTheme;
              final p = Palette.of(context);
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: CustomScrollView(slivers: [
                  const SliverAppBar(floating: true, snap: true, title: Text('Guides')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
                      child: Text('Salaries, interviews, resumes and roadmaps for mobile developers in India.', style: t.bodyMedium?.copyWith(color: p.muted)),
                    ),
                  ),
                  if (s.loading)
                    const SliverFillRemaining(hasScrollBody: true, child: SkeletonList(count: 4, leading: false))
                  else if (s.posts.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: ErrorView(message: s.error ?? 'No guides yet.', onRetry: cubit.load))
                  else ...[
                    SliverToBoxAdapter(child: _Featured(post: s.posts.first, onTap: () => cubit.open(s.posts.first))),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxxl),
                      sliver: SliverList.separated(
                        itemCount: s.posts.length - 1,
                        separatorBuilder: (_, __) => Divider(color: p.line),
                        itemBuilder: (_, i) => _Row(post: s.posts[i + 1], onTap: () => cubit.open(s.posts[i + 1])),
                      ),
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
      );
}

String _meta(BlogPost p) => [if (p.published != null) Fmt.date(p.published!), if (p.readingMinutes != null) '${p.readingMinutes} min read'].join('  ·  ');

class _Featured extends StatelessWidget {
  const _Featured({required this.post, required this.onTap});
  final BlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 6,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.green, AppColors.greenBright, AppColors.gold])),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LATEST${post.tags.isEmpty ? '' : '  ·  ${post.tags.first.toUpperCase()}'}', style: t.labelSmall?.copyWith(color: p.accent)),
                const SizedBox(height: Space.sm + 2),
                Text(post.title, style: t.titleLarge?.copyWith(height: 1.3)),
                const SizedBox(height: Space.sm),
                Text(post.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: p.muted)),
                const SizedBox(height: Space.lg),
                Row(children: [
                  Expanded(child: Text(_meta(post), style: t.bodySmall?.copyWith(color: p.faint))),
                  Text('Read', style: t.bodyMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 17, color: p.accent),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.post, required this.onTap});
  final BlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (post.tags.isNotEmpty) Text(post.tags.first.toUpperCase(), style: t.labelSmall?.copyWith(color: p.accent)),
          const SizedBox(height: 6),
          Text(post.title, style: t.titleMedium),
          const SizedBox(height: 6),
          Text(post.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: p.muted, fontSize: 13.5)),
          const SizedBox(height: Space.sm),
          Text(_meta(post), style: t.bodySmall?.copyWith(color: p.faint)),
        ]),
      ),
    );
  }
}
