# Testing Guide for Favorite Authors + Search + Feed Features

## Features Overview

This document describes how to test the new features:
1. **Favorite Authors** - Add and manage favorite Medium authors
2. **Mixed Posts Feed** - View latest posts from favorite authors on home screen
3. **Search** - Search for Medium posts and add authors to favorites from results

## Testing Instructions

### Feature A: Favorite Authors

#### Adding a Favorite Author
1. Open the app
2. Tap the **heart icon** (♥) in the app bar to go to Favorite Authors screen
3. Tap the **+** button (or "Add Author" button if list is empty)
4. Enter a Medium username without the @ symbol (e.g., `johndoe`)
5. Tap "Add Author"
6. The author should appear in your favorites list

#### Verifying Persistence
1. Add one or more authors to favorites
2. Close the app completely
3. Reopen the app
4. Go to Favorite Authors screen
5. Verify your favorites are still there

#### Removing a Favorite Author
1. Go to Favorite Authors screen
2. Either:
   - Swipe left on an author and confirm removal
   - Tap the delete icon on the right and confirm
3. Verify the author is removed from the list

### Feature B: Mixed Posts Feed

#### Viewing the Feed
1. Add at least 2 favorite authors
2. Go to the home screen
3. Scroll down past the URL input section
4. You should see "Latest Posts" section with post cards

#### Verifying Mixed Posts
1. Add multiple favorite authors
2. Look at the feed - posts should be **interleaved** from different authors
3. Consecutive posts should typically be from different authors

#### URL Cleaning Verification
1. Tap on any post card in the feed
2. The WebView should load the Freedium page
3. Check that the URL in the browser has **no query parameters** (no `?source=...`)
4. The URL format should be: `https://freedium.cfd/https://medium.com/[author]/[article-slug-id]`

#### Empty State
1. Remove all favorite authors
2. Return to home screen
3. You should see "No Favorite Authors" message with a button to add authors

#### Refresh
1. Pull down on the home screen to refresh the feed
2. Or tap "Refresh" button next to "Latest Posts" header

### Feature C: Search

#### Searching for Posts
1. Tap the **search icon** (🔍) in the app bar
2. Enter a search query (e.g., "flutter development")
3. Press search/enter
4. Results should appear as post cards

#### Opening Search Results
1. Perform a search
2. Tap on any result card
3. The post should open in Freedium WebView
4. Verify URL has no query parameters

#### Adding Author from Search Results
1. Perform a search
2. On any result card, tap the **heart icon**
3. The icon should turn filled/red
4. A snackbar should confirm the author was added
5. Go to Favorite Authors screen to verify

#### Removing Author from Search Results
1. Search for posts from an author already in favorites
2. The heart icon should be filled/red
3. Tap it to remove the author from favorites
4. Icon should become outlined
5. Snackbar should confirm removal

## URL Cleaning Verification

The app removes query parameters from Medium URLs before opening them via Freedium.

**Test cases:**
1. Original URL: `/@author/article-name-abc123?source=search_post`
2. After cleaning: `/@author/article-name-abc123`
3. Final Freedium URL: `https://freedium.cfd/https://medium.com/@author/article-name-abc123`

**What to check:**
- No `?source=` in the final URL
- No other query parameters
- The article loads correctly on Freedium

## Edge Cases to Test

1. **Invalid author name**: Try adding an author that doesn't exist
   - Should show error message

2. **Network errors**: Turn off internet and try:
   - Adding an author (should show error)
   - Refreshing feed (should handle gracefully)
   - Searching (should show error)

3. **Empty search query**: Press search with empty input
   - Should not crash, show appropriate state

4. **Duplicate author**: Try adding same author twice
   - Should not create duplicates

5. **Special characters**: Try searching for queries with special characters
   - Should handle encoding properly

## Known Limitations

1. Post titles may not always be available (depends on Medium's HTML structure)
2. Author validation requires network connectivity
3. Search results depend on Medium's search page availability
