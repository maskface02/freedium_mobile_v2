import 'package:flutter/foundation.dart';
import 'package:freedium_mobile/core/constants/app_constants.dart';
import 'package:freedium_mobile/features/favorites/domain/post.dart';
import 'package:http/http.dart' as http;

/// Service for interacting with Medium to fetch author posts.
class MediumService {
  static const int _maxPostsPerAuthor = 10;
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Builds the Medium author profile URL.
  static String buildMediumAuthorUrl(String authorName) {
    return 'https://medium.com/@$authorName';
  }

  /// Cleans a Medium href by removing query parameters.
  /// Converts: `/gitconnected/article-slug-123?source=...`
  /// To: `/gitconnected/article-slug-123`
  static String cleanMediumHrefToUri(String href) {
    // Handle both absolute URLs and relative paths
    String path = href;

    // If it's a full URL, extract the path
    if (href.startsWith('http://') || href.startsWith('https://')) {
      try {
        final uri = Uri.parse(href);
        path = uri.path;
      } catch (e) {
        debugPrint('Failed to parse URL: $href');
        return href;
      }
    }

    // Remove query string if present
    final queryIndex = path.indexOf('?');
    if (queryIndex != -1) {
      path = path.substring(0, queryIndex);
    }

    // Remove fragment if present
    final fragmentIndex = path.indexOf('#');
    if (fragmentIndex != -1) {
      path = path.substring(0, fragmentIndex);
    }

    return path;
  }

  /// Converts a cleaned URI path to a full Medium URL.
  static String uriToMediumUrl(String uri) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return uri;
    }
    return 'https://medium.com$uri';
  }

  /// Converts a Medium URL to a Freedium URL using the project's format.
  static String toFreediumUrl(String mediumUrl, {String? freediumBaseUrl}) {
    final baseUrl = freediumBaseUrl ?? AppConstants.freediumUrl;
    // The project uses: freedium.cfd + medium URL path
    // Example: https://freedium.cfd/https://medium.com/...
    return '$baseUrl/$mediumUrl';
  }

  /// Fetches the latest posts from an author's Medium profile.
  Future<List<Post>> fetchAuthorPosts(
    String authorName, {
    int maxPosts = _maxPostsPerAuthor,
    String? freediumBaseUrl,
  }) async {
    final profileUrl = buildMediumAuthorUrl(authorName);
    final posts = <Post>[];

    try {
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('Failed to fetch author page: ${response.statusCode}');
        return posts;
      }

      final html = response.body;
      posts.addAll(_parsePostsFromHtml(html, authorName, freediumBaseUrl));

      // Limit and dedupe
      final seen = <String>{};
      final uniquePosts = <Post>[];
      for (final post in posts) {
        if (!seen.contains(post.mediumUrl)) {
          seen.add(post.mediumUrl);
          uniquePosts.add(post);
          if (uniquePosts.length >= maxPosts) break;
        }
      }

      return uniquePosts;
    } catch (e) {
      debugPrint('Error fetching posts for $authorName: $e');
      return posts;
    }
  }

  /// Parses posts from the HTML of an author's profile page.
  List<Post> _parsePostsFromHtml(
    String html,
    String authorName,
    String? freediumBaseUrl,
  ) {
    final posts = <Post>[];

    // Find all anchor tags with href containing article-like paths
    // Medium article URLs typically have a 12-character hex ID at the end
    final anchorRegex = RegExp(
      r'<a[^>]*href="([^"]*-[a-f0-9]{8,12}(?:\?[^"]*)?)"[^>]*>',
      caseSensitive: false,
    );

    // Also extract title from h2/h3 tags near anchors or the anchor text itself
    final anchorWithTitleRegex = RegExp(
      r'<a[^>]*href="([^"]*-[a-f0-9]{8,12}(?:\?[^"]*)?)"[^>]*>(?:<[^>]*>)*([^<]*)',
      caseSensitive: false,
    );

    // First, try to extract with titles
    final matchesWithTitle = anchorWithTitleRegex.allMatches(html);
    for (final match in matchesWithTitle) {
      final href = match.group(1);
      var title = match.group(2)?.trim();

      if (href == null || href.isEmpty) continue;

      // Skip non-article links
      if (_isNonArticleLink(href)) continue;

      final cleanedUri = cleanMediumHrefToUri(href);
      final mediumUrl = uriToMediumUrl(cleanedUri);
      final freediumUrl = toFreediumUrl(mediumUrl, freediumBaseUrl: freediumBaseUrl);

      // Clean up title
      if (title != null && title.isNotEmpty && title.length > 200) {
        title = null; // Title too long, likely not a real title
      }

      posts.add(Post(
        title: title?.isNotEmpty == true ? title : null,
        mediumUrl: mediumUrl,
        freediumUrl: freediumUrl,
        authorName: authorName,
      ));
    }

    // If no posts found with title regex, try simpler approach
    if (posts.isEmpty) {
      final matches = anchorRegex.allMatches(html);
      for (final match in matches) {
        final href = match.group(1);
        if (href == null || href.isEmpty) continue;
        if (_isNonArticleLink(href)) continue;

        final cleanedUri = cleanMediumHrefToUri(href);
        final mediumUrl = uriToMediumUrl(cleanedUri);
        final freediumUrl = toFreediumUrl(mediumUrl, freediumBaseUrl: freediumBaseUrl);

        posts.add(Post(
          mediumUrl: mediumUrl,
          freediumUrl: freediumUrl,
          authorName: authorName,
        ));
      }
    }

    return posts;
  }

  /// Checks if a link is NOT an article (e.g., navigation links, user profiles).
  bool _isNonArticleLink(String href) {
    // Skip user profile links that don't have article IDs
    if (href.startsWith('/@') && !href.contains('-')) return true;
    // Skip tag/topic pages
    if (href.startsWith('/tag/')) return true;
    // Skip about pages
    if (href.contains('/about')) return true;
    // Skip followers/following
    if (href.contains('/followers') || href.contains('/following')) return true;
    // Skip membership
    if (href.contains('/membership')) return true;
    // Skip plans
    if (href.contains('/plans')) return true;

    return false;
  }

  /// Validates if an author exists by checking if the profile URL returns 200.
  Future<bool> validateAuthor(String authorName) async {
    try {
      final profileUrl = buildMediumAuthorUrl(authorName);
      final response = await http.head(
        Uri.parse(profileUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error validating author $authorName: $e');
      return false;
    }
  }
}
