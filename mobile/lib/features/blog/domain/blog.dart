import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';

class BlogPost extends Equatable {
  const BlogPost({required this.id, required this.url, required this.title, required this.summary, this.published, this.tags = const [], this.readingMinutes});
  final String id;
  final String url;
  final String title;
  final String summary;
  final DateTime? published;
  final List<String> tags;
  final int? readingMinutes;
  @override
  List<Object?> get props => [id, url, title, summary, published, tags, readingMinutes];
}

abstract interface class BlogRepository {
  Future<Result<List<BlogPost>>> posts();
}

@injectable
class GetBlogPosts implements UseCase<List<BlogPost>, NoParams> {
  const GetBlogPosts(this._repo);
  final BlogRepository _repo;
  @override
  Future<Result<List<BlogPost>>> call(NoParams p) => _repo.posts();
}
