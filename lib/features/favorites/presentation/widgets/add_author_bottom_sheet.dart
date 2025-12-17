import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedium_mobile/features/favorites/application/favorite_authors_provider.dart';

/// Bottom sheet for adding a new favorite author.
class AddAuthorBottomSheet extends ConsumerStatefulWidget {
  const AddAuthorBottomSheet({super.key});

  @override
  ConsumerState<AddAuthorBottomSheet> createState() =>
      _AddAuthorBottomSheetState();
}

class _AddAuthorBottomSheetState extends ConsumerState<AddAuthorBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addAuthor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authorName = _controller.text.trim();

    // Optionally validate the author exists on Medium
    final mediumService = ref.read(mediumServiceProvider);
    final isValid = await mediumService.validateAuthor(authorName);

    if (!isValid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Author not found on Medium. Please check the username.';
        });
      }
      return;
    }

    final success = await ref.read(favoriteAuthorsProvider.notifier).addAuthor(authorName);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('@$authorName added to favorites')),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to add author. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Favorite Author',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the Medium username (without @)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'username',
                  prefixIcon: const Icon(Icons.person),
                  prefixText: '@',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  errorText: _error,
                ),
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  // Basic validation for username format
                  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim())) {
                    return 'Invalid username format';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _addAuthor(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _addAuthor,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Add Author'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the bottom sheet for adding a favorite author.
Future<bool?> showAddAuthorBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AddAuthorBottomSheet(),
  );
}
