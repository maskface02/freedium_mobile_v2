import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedium_mobile/features/favorites/application/favorite_authors_provider.dart';
import 'package:freedium_mobile/features/favorites/presentation/widgets/add_author_bottom_sheet.dart';

/// Screen displaying the list of favorite authors.
class FavoriteAuthorsScreen extends ConsumerWidget {
  const FavoriteAuthorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoriteAuthorsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Authors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showAddAuthorBottomSheet(context),
            tooltip: 'Add author',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (favoritesState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (favoritesState.authors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Favorite Authors',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your favorite Medium authors to see their latest posts on the home screen.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => showAddAuthorBottomSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Author'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(favoriteAuthorsProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: favoritesState.authors.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final author = favoritesState.authors[index];
                return Dismissible(
                  key: Key(author.authorName),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: colorScheme.error,
                    child: Icon(
                      Icons.delete,
                      color: colorScheme.onError,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Remove Author'),
                        content: Text(
                          'Remove @${author.authorName} from your favorites?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ref.read(favoriteAuthorsProvider.notifier).removeAuthor(author);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('@${author.authorName} removed from favorites'),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        author.authorName.isNotEmpty
                            ? author.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text('@${author.authorName}'),
                    subtitle: Text(
                      author.profileUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove Author'),
                            content: Text(
                              'Remove @${author.authorName} from your favorites?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          ref.read(favoriteAuthorsProvider.notifier).removeAuthor(author);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('@${author.authorName} removed from favorites'),
                            ),
                          );
                        }
                      },
                      tooltip: 'Remove from favorites',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: favoritesState.authors.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => showAddAuthorBottomSheet(context),
              tooltip: 'Add author',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
