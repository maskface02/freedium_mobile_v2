import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freedium_mobile/features/favorites/domain/author.dart';

/// Service for persisting favorite authors using SharedPreferences.
class FavoriteAuthorsService {
  static const String _favoritesKey = 'favorite_authors';

  /// Loads all favorite authors from storage.
  Future<List<Author>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_favoritesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => Author.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
      return [];
    }
  }

  /// Saves all favorite authors to storage.
  Future<bool> saveFavorites(List<Author> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = favorites.map((author) => author.toJson()).toList();
      final jsonString = json.encode(jsonList);
      return await prefs.setString(_favoritesKey, jsonString);
    } catch (e) {
      debugPrint('Failed to save favorites: $e');
      return false;
    }
  }

  /// Adds an author to favorites.
  Future<bool> addFavorite(Author author) async {
    final favorites = await loadFavorites();
    if (!favorites.contains(author)) {
      favorites.add(author);
      return await saveFavorites(favorites);
    }
    return true;
  }

  /// Removes an author from favorites.
  Future<bool> removeFavorite(Author author) async {
    final favorites = await loadFavorites();
    favorites.removeWhere((a) => a.authorName == author.authorName);
    return await saveFavorites(favorites);
  }

  /// Checks if an author is in favorites.
  Future<bool> isFavorite(String authorName) async {
    final favorites = await loadFavorites();
    return favorites.any((a) => a.authorName == authorName);
  }
}
