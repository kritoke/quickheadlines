## 1. AppHeader Simplification

- [x] 1.1 Remove tab-related props (`viewHref`, `viewIcon`) from AppHeader component
- [x] 1.2 Replace view switch logic to read directly from `$page` store using `$page.url.searchParams.get('tab')`
- [x] 1.3 Simplify icon determination logic using `$page.url.pathname` comparison
- [x] 1.4 Add null checks for server-side rendering compatibility in `$page` store usage

## 2. Feed Page Cleanup

- [x] 2.1 Ensure feed page reads current tab exclusively from `$page.url.searchParams.get('tab')`
- [x] 2.2 Remove redundant state synchronization logic (`setFeedsTab`, `lastLoadedTab`)
- [x] 2.3 Simplify timeline link derivation to use direct URL construction
- [x] 2.4 Update AppHeader usage to remove tab-related props

## 3. Timeline Page Fixes

- [x] 3.1 Replace `onMount` initialization with `$effect` for proper reactivity to URL changes
- [x] 3.2 Ensure timeline page reads current tab from `$page.url.searchParams.get('tab')`
- [x] 3.3 Remove redundant state management (`lastLoadedTab`, complex sync logic)
- [x] 3.4 Add proper error and empty state handling for timeline items
- [x] 3.5 Update AppHeader usage to remove tab-related props

## 4. State Management Cleanup

- [x] 4.1 Remove unnecessary state synchronization between pages
- [x] 4.2 Eliminate redundant `navigationStore.feedsTab` usage if possible
- [x] 4.3 Ensure all components rely solely on URL parameters as single source of truth

## 5. Testing and Verification

- [x] 5.1 Test tab persistence: /?tab=Tech → /timeline?tab=Tech → /?tab=Tech
- [x] 5.2 Test special character handling: "AI & ML" tab navigation works correctly
- [x] 5.3 Test empty timeline scenarios show proper user feedback
- [x] 5.4 Verify all existing frontend tests pass
- [x] 5.5 Verify all existing backend tests pass
- [x] 5.6 Test global timeline (`tab=all`) functionality remains intact
- [x] 5.7 Test mobile tab navigation continues to work correctly

## 6. Build and Deployment

- [x] 6.1 Run `just nix-build` to ensure successful compilation
- [x] 6.2 Verify server starts correctly with new changes
- [x] 6.3 Test in browser to confirm fixes work as expected
- [x] 6.4 Commit changes with appropriate commit message
- [x] 6.5 Push changes to remote repository