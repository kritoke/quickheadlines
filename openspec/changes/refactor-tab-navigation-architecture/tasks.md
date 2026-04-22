## 1. Remove Intermediate Tab State

- [x] 1.1 Remove `activeTab` property from `feedState` store
- [x] 1.2 Remove `setActiveTab` and `getActiveTab` functions from feed store  
- [x] 1.3 Remove `feedsTab` state from `navigationStore`
- [x] 1.4 Remove `setFeedsTab` and `getFeedsTab` functions from navigation store
- [x] 1.5 Update all component imports to remove unused store references

## 2. Create Navigation Service

- [x] 2.1 Create `src/lib/services/navigationService.ts` with NavigationService class
- [x] 2.2 Implement `navigateToTimeline(currentTab: string)` method
- [x] 2.3 Implement `navigateToFeeds(currentTab: string)` method  
- [x] 2.4 Implement `getCurrentTab(): string` helper method
- [x] 2.5 Add proper URL encoding/decoding for special characters
- [x] 2.6 Add null checks and error handling for SSR compatibility

## 3. Simplify AppHeader Component

- [x] 3.1 Remove all navigation logic from AppHeader component
- [x] 3.2 Remove `$page` store usage from AppHeader  
- [x] 3.3 Update AppHeader props interface to accept only presentation data
- [x] 3.4 Replace view switch button logic with callback props
- [x] 3.5 Ensure tabs selector works with passed props only
- [x] 3.6 Add proper type safety and documentation

## 4. Standardize Feed Page Pattern

- [ ] 4.1 Replace current initialization logic with `onMount` pattern
- [ ] 4.2 Remove all intermediate tab state usage from feed page
- [ ] 4.3 Implement URL-based tab reading using NavigationService
- [ ] 4.6 Update AppHeader usage to pass required props only
- [ ] 4.7 Add proper effect guards to prevent infinite loops
- [ ] 4.8 Ensure handleTabChange uses NavigationService

## 5. Standardize Timeline Page Pattern

- [ ] 5.1 Replace current initialization logic with `onMount` pattern  
- [ ] 5.2 Remove all intermediate tab state usage from timeline page
- [ ] 5.3 Implement URL-based tab reading using NavigationService
- [ ] 5.4 Update AppHeader usage to pass required props only
- [ ] 5.5 Add proper effect guards to prevent infinite loops
- [ ] 5.6 Ensure handleTabChange uses NavigationService
- [ ] 5.7 Fix handleRetry to use current URL tab

## 6. Comprehensive Testing

- [ ] 6.1 Test tab persistence: /?tab=Tech → /timeline?tab=Tech → /?tab=Tech
- [ ] 6.2 Test special character handling: "AI & ML" tab navigation
- [ ] 6.3 Test global timeline (tab=all) functionality
- [ ] 6.4 Verify no excessive API calls or console logging
- [ ] 6.5 Test mobile tab navigation continues to work
- [ ] 6.6 Verify all existing frontend tests pass
- [ ] 6.7 Verify all existing backend tests pass

## 7. Build and Deployment

- [ ] 7.1 Run `just nix-build` to ensure successful compilation
- [ ] 7.2 Verify server starts correctly with new architecture
- [ ] 7.3 Test in browser to confirm all fixes work as expected
- [ ] 7.4 Commit changes with appropriate commit message
- [ ] 7.5 Push changes to remote repository