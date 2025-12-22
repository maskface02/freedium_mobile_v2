import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedium_mobile/core/services/favorite_authors_service.dart';
import 'package:freedium_mobile/core/services/medium_service.dart';
import 'package:freedium_mobile/features/favorites/domain/author.dart';
import 'package:freedium_mobile/features/favorites/domain/post.dart';

/// State for the favorite authors feature.
class FavoriteAuthorsState {
  final List<Author> authors;
  final bool isLoading;
  final String? error;

  const FavoriteAuthorsState({
    this.authors = const [],
    this.isLoading = false,
    this.error,
  });

  FavoriteAuthorsState copyWith({
    List<Author>? authors,
    bool? isLoading,
    String? error,
  }) {
    return FavoriteAuthorsState(
      authors: authors ?? this.authors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing favorite authors.
class FavoriteAuthorsNotifier extends Notifier<FavoriteAuthorsState> {
  late final FavoriteAuthorsService _service;

  @override
  FavoriteAuthorsState build() {
    _service = ref.read(favoriteAuthorsServiceProvider);
    _loadFavorites();
    return const FavoriteAuthorsState(isLoading: true);
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _service.loadFavorites();
      state = state.copyWith(authors: favorites, isLoading: false);
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Adds an author to favorites by name.
  Future<bool> addAuthor(String authorName) async {
    final trimmedName = authorName.trim();
    if (trimmedName.isEmpty) return false;

    // Check if already in favorites
    if (state.authors.any((a) => a.authorName == trimmedName)) {
      return true; // Already exists
    }

    final author = Author.fromName(trimmedName);
    final success = await _service.addFavorite(author);

    if (success) {
      state = state.copyWith(
        authors: [...state.authors, author],
      );
      // Refresh the feed
      ref.invalidate(feedProvider);
    }

    return success;
  }

  /// Removes an author from favorites.
  Future<bool> removeAuthor(Author author) async {
    final success = await _service.removeFavorite(author);

    if (success) {
      state = state.copyWith(
        authors: state.authors.where((a) => a.authorName != author.authorName).toList(),
      );
      // Refresh the feed
      ref.invalidate(feedProvider);
    }

    return success;
  }

  /// Checks if an author is in favorites.
  bool isFavorite(String authorName) {
    return state.authors.any((a) => a.authorName == authorName);
  }

  /// Refreshes the favorites list from storage.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadFavorites();
  }
}

/// Provider for the FavoriteAuthorsService.
final favoriteAuthorsServiceProvider = Provider((ref) => FavoriteAuthorsService());

/// Provider for the MediumService.
final mediumServiceProvider = Provider((ref) => MediumService());

/// Provider for favorite authors state.
final favoriteAuthorsProvider = NotifierProvider<FavoriteAuthorsNotifier, FavoriteAuthorsState>(
  FavoriteAuthorsNotifier.new,
);

/// State for the home feed.
class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final String? error;
  final bool isEmpty;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.isEmpty = false,
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    String? error,
    bool? isEmpty,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isEmpty: isEmpty ?? this.isEmpty,
    );
  }
}

/// Notifier for managing the home feed with mixed posts from favorite authors.
class FeedNotifier extends Notifier<FeedState> {
  static const int _maxRetries = 10;

  @override
  FeedState build() {
    _loadFeed();
    return const FeedState(isLoading: true);
  }

  Future<void> _loadFeed() async {
    final favorites = ref.read(favoriteAuthorsProvider);
    
    // Wait for favorites to load if still loading (with retry limit)
    if (favorites.isLoading) {
      await _waitForFavorites();
    }

    final currentFavorites = ref.read(favoriteAuthorsProvider);
    if (currentFavorites.authors.isEmpty) {
      state = state.copyWith(isLoading: false, isEmpty: true, posts: []);
      return;
    }

    final mediumService = ref.read(mediumServiceProvider);
    
    // Fetch posts concurrently for all authors
    final futures = currentFavorites.authors.map((author) async {
      try {
        return await mediumService.fetchAuthorPosts(
          author.authorName,
          maxPosts: 5,
        );
      } catch (e) {
        debugPrint('Failed to fetch posts for ${author.authorName}: $e');
        return <Post>[];
      }
    }).toList();

    final results = await Future.wait(futures);
    final allPosts = results.where((posts) => posts.isNotEmpty).toList();

    // Mix posts round-robin style
    final mixedPosts = _mixPostsRoundRobin(allPosts);

    state = state.copyWith(
      posts: mixedPosts,
      isLoading: false,
      isEmpty: mixedPosts.isEmpty,
    );
  }

  /// Waits for favorites to finish loading with a retry limit.
  Future<void> _waitForFavorites() async {
    int retries = 0;
    while (ref.read(favoriteAuthorsProvider).isLoading && retries < _maxRetries) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
  }

  /// Mixes posts from multiple authors in a round-robin fashion.
  List<Post> _mixPostsRoundRobin(List<List<Post>> postLists) {
    if (postLists.isEmpty) return [];

    final mixed = <Post>[];
    final indices = List<int>.filled(postLists.length, 0);
    final seen = <String>{};

    int emptyCount = 0;
    while (emptyCount < postLists.length) {
      emptyCount = 0;
      for (int i = 0; i < postLists.length; i++) {
        if (indices[i] < postLists[i].length) {
          final post = postLists[i][indices[i]];
          indices[i]++;
          // Dedupe by URL
          if (!seen.contains(post.mediumUrl)) {
            seen.add(post.mediumUrl);
            mixed.add(post);
          }
        } else {
          emptyCount++;
        }
      }
    }

    return mixed;
  }

  /// Refreshes the feed.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadFeed();
  }
}

/// Provider for the home feed.
final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
