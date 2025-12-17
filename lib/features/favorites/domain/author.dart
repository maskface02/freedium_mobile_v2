/// Represents a Medium author that the user has favorited.
class Author {
  final String authorName;
  final String profileUrl;

  const Author({required this.authorName, required this.profileUrl});

  /// Creates an Author from just the author name, constructing the profile URL.
  factory Author.fromName(String authorName) {
    return Author(
      authorName: authorName,
      profileUrl: 'https://medium.com/@$authorName',
    );
  }

  /// Creates an Author from JSON map (for persistence).
  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      authorName: json['authorName'] as String,
      profileUrl: json['profileUrl'] as String,
    );
  }

  /// Converts the Author to a JSON map (for persistence).
  Map<String, dynamic> toJson() {
    return {'authorName': authorName, 'profileUrl': profileUrl};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Author && other.authorName == authorName;
  }

  @override
  int get hashCode => authorName.hashCode;

  @override
  String toString() => 'Author(authorName: $authorName, profileUrl: $profileUrl)';
}
