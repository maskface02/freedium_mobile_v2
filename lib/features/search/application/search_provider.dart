import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedium_mobile/core/services/medium_service.dart';
import 'package:freedium_mobile/features/favorites/application/favorite_authors_provider.dart';
import 'package:freedium_mobile/features/favorites/domain/post.dart';
import 'package:http/http.dart' as http;

/// State for search results.
class SearchState {
  final List<Post> results;
  final bool isLoading;
  final String? error;
  final String query;
  final SearchType searchType;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
    this.searchType = SearchType.posts,
  });

  SearchState copyWith({
    List<Post>? results,
    bool? isLoading,
    String? error,
    String? query,
    SearchType? searchType,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
      searchType: searchType ?? this.searchType,
    );
  }
}

enum SearchType { posts, topics }

/// Notifier for managing search state.
class SearchNotifier extends Notifier<SearchState> {
  static const Duration _requestTimeout = Duration(seconds: 15);

  @override
  SearchState build() {
    return const SearchState();
  }

  /// Searches for posts on Medium using a query.
  Future<void> searchPosts(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(results: [], isLoading: false, query: '');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      query: query,
      searchType: SearchType.posts,
    );

    try {
      final posts = await _fetchSearchResults(query.trim());
      state = state.copyWith(results: posts, isLoading: false);
    } catch (e) {
      debugPrint('Search error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Search failed. Please try again.',
      );
    }
  }

  /// Fetches search results from Medium.
  Future<List<Post>> _fetchSearchResults(String query) async {
    final posts = <Post>[];
    
    // Encode the search query for URL
    final encodedQuery = Uri.encodeComponent(query);
    final searchUrl = 'https://medium.com/search?q=$encodedQuery';

    try {
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('Search request failed: ${response.statusCode}');
        return posts;
      }

      final html = response.body;
      posts.addAll(_parseSearchResults(html));

      return posts;
    } catch (e) {
      debugPrint('Error fetching search results: $e');
      return posts;
    }
  }

  /// Parses search results from Medium search page HTML.
  /// 
  /// Note: This uses regex-based HTML parsing which is fragile and may break
  /// if Medium changes their HTML structure. The patterns are designed based on
  /// Medium's current HTML structure as of late 2024.
  /// 
  /// Regex patterns explained:
  /// - `articleRegex`: Matches anchor tags with href containing `/@author/` pattern
  ///   followed by an article path ending with 8-12 character hex ID.
  /// - `titleRegex`: Similar pattern but captures the text content after the anchor
  ///   opening tag, skipping nested HTML tags.
  List<Post> _parseSearchResults(String html) {
    final posts = <Post>[];
    final seen = <String>{};

    // Find article links with author info extracted from URL path.
    // Medium URLs typically follow: /@author/article-title-abc123def456
    // Pattern captures: full href, author name (from /@author/ segment)
    final articleRegex = RegExp(
      r'<a[^>]*href="([^"]*/@([^/]+)/[^"]*-[a-f0-9]{8,12}(?:\?[^"]*)?)"[^>]*>',
      caseSensitive: false,
    );

    // Extract titles from anchor text content.
    // Pattern: Same article matching but also captures text after skipping nested tags.
    // The (?:<[^>]*>)* skips inline tags like <span>, <strong>, <h2>, etc.
    final titleRegex = RegExp(
      r'<a[^>]*href="([^"]*-[a-f0-9]{8,12}(?:\?[^"]*)?)"[^>]*>(?:<[^>]*>)*([^<]+)',
      caseSensitive: false,
    );

    // Extract articles with author info from URL
    final articleMatches = articleRegex.allMatches(html);
    for (final match in articleMatches) {
      final href = match.group(1);
      final authorName = match.group(2);

      if (href == null || href.isEmpty || authorName == null) continue;
      if (_isNonArticleLink(href)) continue;

      final cleanedUri = MediumService.cleanMediumHrefToUri(href);
      final mediumUrl = MediumService.uriToMediumUrl(cleanedUri);

      if (seen.contains(mediumUrl)) continue;
      seen.add(mediumUrl);

      final freediumUrl = MediumService.toFreediumUrl(mediumUrl);

      posts.add(Post(
        mediumUrl: mediumUrl,
        freediumUrl: freediumUrl,
        authorName: authorName,
      ));
    }

    // Try to find titles and match them to posts
    final titleMatches = titleRegex.allMatches(html);
    for (final match in titleMatches) {
      final href = match.group(1);
      var title = match.group(2)?.trim();

      if (href == null || href.isEmpty) continue;
      if (title == null || title.isEmpty || title.length > 200) continue;

      final cleanedUri = MediumService.cleanMediumHrefToUri(href);
      final mediumUrl = MediumService.uriToMediumUrl(cleanedUri);

      // Try to find existing post and update title
      final existingIndex = posts.indexWhere((p) => p.mediumUrl == mediumUrl);
      if (existingIndex != -1 && posts[existingIndex].title == null) {
        final existing = posts[existingIndex];
        posts[existingIndex] = Post(
          title: title,
          mediumUrl: existing.mediumUrl,
          freediumUrl: existing.freediumUrl,
          authorName: existing.authorName,
        );
      }
    }

    // Limit results
    return posts.take(20).toList();
  }

  /// Checks if a link is NOT an article.
  bool _isNonArticleLink(String href) {
    if (href.startsWith('/@') && !href.contains('-')) return true;
    if (href.startsWith('/tag/')) return true;
    if (href.contains('/about')) return true;
    if (href.contains('/followers') || href.contains('/following')) return true;
    if (href.contains('/membership')) return true;
    if (href.contains('/plans')) return true;
    return false;
  }

  /// Sets the search type (posts or topics).
  void setSearchType(SearchType type) {
    state = state.copyWith(searchType: type, results: []);
  }

  /// Clears the search results.
  void clear() {
    state = const SearchState();
  }
}

/// Provider for search state.
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
