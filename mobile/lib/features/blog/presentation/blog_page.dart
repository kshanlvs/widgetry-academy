import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/di/injection.dart';
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
          appBar: AppBar(title: const Text('Career guides')),
          body: BlocBuilder<BlogCubit, BlogState>(
            builder: (context, s) {
              final cubit = context.read<BlogCubit>();
              if (s.loading) return const LoadingView();
              if (s.posts.isEmpty) return ErrorView(message: s.error ?? 'No articles yet.', onRetry: cubit.load);
              final t = Theme.of(context).textTheme;
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = s.posts[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => cubit.open(p),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (p.tags.isNotEmpty) Text(p.tags.first.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text(p.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.3)),
                            const SizedBox(height: 6),
                            Text(p.summary, style: t.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Text([if (p.published != null) Fmt.date(p.published!), if (p.readingMinutes != null) '${p.readingMinutes} min read'].join(' · '), style: t.bodySmall),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
}
