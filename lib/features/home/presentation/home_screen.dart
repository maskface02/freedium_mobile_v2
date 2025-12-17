import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedium_mobile/core/constants/app_constants.dart';
import 'package:freedium_mobile/core/services/update_service.dart';
import 'package:freedium_mobile/features/favorites/application/favorite_authors_provider.dart';
import 'package:freedium_mobile/features/favorites/presentation/favorite_authors_screen.dart';
import 'package:freedium_mobile/features/favorites/presentation/widgets/add_author_bottom_sheet.dart';
import 'package:freedium_mobile/features/favorites/presentation/widgets/post_card.dart';
import 'package:freedium_mobile/features/home/application/home_provider.dart';
import 'package:freedium_mobile/features/home/presentation/widgets/about_dialog.dart';
import 'package:freedium_mobile/features/home/presentation/widgets/theme_chooser_bottom_sheet.dart';
import 'package:freedium_mobile/features/home/presentation/widgets/update_card.dart';
import 'package:freedium_mobile/features/search/presentation/search_screen.dart';
import 'package:freedium_mobile/features/webview/presentation/webview_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isUpdateCardDismissed = false;

  void _navigateToPost(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebviewScreen(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);
    final updateAsync = ref.watch(updateCheckProvider);
    final feedState = ref.watch(feedProvider);
    final favoritesState = ref.watch(favoriteAuthorsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            ),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FavoriteAuthorsScreen(),
              ),
            ),
            tooltip: 'Favorite Authors',
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => showThemeChooserBottomSheet(context),
            tooltip: 'Theme',
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => showAppAboutDialog(context, ref),
            tooltip: 'About',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // Update card and URL input section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    updateAsync.when(
                      data: (updateInfo) {
                        if (updateInfo != null && !_isUpdateCardDismissed) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: UpdateCard(
                              updateInfo: updateInfo,
                              onDismissed: () =>
                                  setState(() => _isUpdateCardDismissed = true),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    const Text(
                      AppConstants.appDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: homeState.formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: TextFormField(
                        controller: homeState.urlController,
                        decoration: InputDecoration(
                          hintText: 'Medium URL',
                          prefixIcon: const Icon(Icons.link),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: homeNotifier.pasteFromClipboard,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a URL';
                          }
                          final urlRegExp = RegExp(
                            AppConstants.urlRegExp,
                            caseSensitive: false,
                          );
                          if (!urlRegExp.hasMatch(value)) {
                            return 'Please enter a valid URL';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => homeNotifier.getArticle(context),
                        child: const Text('Get Article'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Feed section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Latest Posts',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (favoritesState.authors.isNotEmpty)
                      TextButton(
                        onPressed: () => ref.read(feedProvider.notifier).refresh(),
                        child: const Text('Refresh'),
                      ),
                  ],
                ),
              ),
            ),
            // Feed content
            if (feedState.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (feedState.isEmpty || favoritesState.authors.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Favorite Authors',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your favorite Medium authors to see their latest posts here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => showAddAuthorBottomSheet(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Author'),
                      ),
                    ],
                  ),
                ),
              )
            else if (feedState.posts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Posts Found',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Could not fetch posts from your favorite authors. Pull down to refresh.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = feedState.posts[index];
                    return PostCard(
                      post: post,
                      onTap: () => _navigateToPost(post.mediumUrl),
                    );
                  },
                  childCount: feedState.posts.length,
                ),
              ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }
}
