/// Represents a Medium post/article.
class Post {
  final String? title;
  final String mediumUrl;
  final String freediumUrl;
  final String authorName;
  final String? excerpt;

  const Post({
    this.title,
    required this.mediumUrl,
    required this.freediumUrl,
    required this.authorName,
    this.excerpt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Post && other.mediumUrl == mediumUrl;
  }

  @override
  int get hashCode => mediumUrl.hashCode;

  @override
  String toString() =>
      'Post(title: $title, mediumUrl: $mediumUrl, authorName: $authorName)';
}
