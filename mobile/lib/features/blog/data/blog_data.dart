import 'package:injectable/injectable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/blog/domain/blog.dart';

part 'blog_data.g.dart';

/// One item of the website's JSON feed (blog/feed.json).
@JsonSerializable(createToJson: false)
class BlogPostModel {
  const BlogPostModel({required this.id, required this.url, required this.title, this.summary = '', this.datePublished, this.tags = const [], this.readingMinutes});
  factory BlogPostModel.fromJson(Map<String, dynamic> json) => _$BlogPostModelFromJson(json);

  final String id;
  final String url;
  final String title;
  @JsonKey(defaultValue: '')
  final String summary;
  @JsonKey(name: 'date_published')
  final String? datePublished;
  @JsonKey(defaultValue: <String>[])
  final List<String> tags;
  @JsonKey(name: 'reading_minutes')
  final int? readingMinutes;

  BlogPost toEntity() => BlogPost(id: id, url: url, title: title, summary: summary, published: DateTime.tryParse(datePublished ?? ''), tags: tags, readingMinutes: readingMinutes);
}

@LazySingleton(as: BlogRepository)
class BlogRepositoryImpl implements BlogRepository {
  BlogRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<BlogPost>>> posts() => guard(() async {
        final json = await _api.getUrl(AppConfig.blogFeedUrl);
        return (json['items'] as List? ?? const []).whereType<Map<String, dynamic>>().map((m) => BlogPostModel.fromJson(m).toEntity()).toList();
      });
}
