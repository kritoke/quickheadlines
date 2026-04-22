## 1. Create Design Tokens File

- [x] 1.1 Create `/frontend/src/lib/design/tokens.ts` with spacing constants (compact: 8px, default: 12px, spacious: 16px)
- [x] 1.2 Add typography constants to tokens.ts (headline: text-xl, body: text-base, auxiliary: text-sm, action: text-xs)
- [x] 1.3 Add elevation/shadow constants to tokens.ts
- [x] 1.4 Export semantic class mappings for use in components

## 2. Update Tailwind Configuration

- [x] 2.1 Update tailwind.config.js to reference design tokens where possible
- [x] 2.2 Ensure dark mode classes work with semantic tokens

## 3. Refactor Core Components

- [x] 3.1 Refactor Card.svelte to use semantic classes exclusively (remove dual variant logic)
- [x] 3.2 Refactor AppHeader.svelte to use consistent spacing and typography
- [x] 3.3 Refactor FeedBox.svelte to use spacing tokens
- [x] 3.4 Refactor TimelineView.svelte to use spacing and typography tokens
- [x] 3.5 Refactor TabSelector.svelte to use consistent spacing

## 4. Update Secondary Components

- [x] 4.1 Update ThemePicker.svelte to use typography tokens
- [x] 4.2 Update LayoutPicker.svelte to use spacing tokens
- [x] 4.3 Update BitsSearchModal.svelte to use spacing and typography tokens
- [x] 4.4 Update Toast.svelte to use spacing tokens

## 5. Update Page Layouts

- [x] 5.1 Refactor +page.svelte (feeds page) to use consistent spacing
- [x] 5.2 Refactor timeline/+page.svelte to use consistent spacing and typography

## 6. Testing and Verification

- [x] 6.1 Run `just nix-build` to verify build succeeds
- [x] 6.2 Verify light theme renders correctly
- [x] 6.3 Verify dark theme renders correctly
- [x] 6.4 Verify custom themes (matrix, retro, ocean, etc.) render correctly
- [x] 6.5 Run frontend tests: `cd frontend && npm run test`
- [x] 6.6 Run Crystal tests: `nix develop . --command crystal spec`
