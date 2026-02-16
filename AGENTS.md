# Agent Instructions

This project uses **OpenSpec** for change tracking and specification management.
All work must be structured as an OpenSpec Change within `openspec/changes/`.

## OpenSpec Workflow

1. **New Change:** Use `/opsx:new <name>` or `/opsx:ff <name>` to start a task.
2. **Implementation:** Use `/opsx:apply <name>` to work through tasks.
3. **Verification:** Use `/opsx:verify <name>` to ensure implementation matches specs.
4. **Archival:** Use `/opsx:archive <name>` to finalize work and sync specs.

## Critical Directives

### 1. The Core Agent Directive

> Execution Context:
> This project is a Nix Spoke. You are running inside a persistent Hub, but the project-specific tools (Crystal 1.18.2, Node.js 22, pnpm) are isolated.
> Rule: For ANY shell command execution (compiling, testing, formatting), you MUST run commands inside the nix devshell. Prefer either: (A) call `just` recipes from inside the devshell (recommended), or (B) use the devshell `--command` with the working-directory semantics your tooling supports.
> - Recommended: `just nix-build` or `nix develop . --command crystal spec`
> - Incorrect: `crystal spec` (without devshell)
> - Incorrect: `shards install` (without devshell)

### 2. The Library/Linker Workaround

Because Crystal 1.18.2 is manually derived and requires specific library paths:

> Library Path Handling:
> If a command fails with a "library not found" error (e.g., libgc.so.1 or libevent), do not attempt to install packages via apt. Instead, verify that the command is being run through the nix develop wrapper, as the flake handles the LD_LIBRARY_PATH internally.

### 3. OpenSpec Discipline

> Task Discipline:
> Agents must create a Change Proposal (`/opsx:new`) before writing code. Archival (`/opsx:archive`) is mandatory for all completed tasks to merge changes into the permanent specs in `openspec/specs/`.

### 4. Why This Is Necessary

OpenCode agents often try to be "helpful" by running commands directly in the shell they find themselves in. In this setup:
- The Base Shell is your "Hub" (which has Go, Node, but NOT Crystal 1.18.2)
- The Sub-Shell created by `nix develop . --command` has the "Spoke" tools

If you don't use the prefix, you will get a `command not found: crystal` error, even though the file is right there in the project.

### 5. Compilation Before Completion

> MANDATORY BUILD CHECK:
> Before EVER saying a task is "done", "complete", "ready for review", or marking it as finished, you MUST run `just nix-build` and verify it succeeds.
>
> **Required command:**
> ```bash
> just nix-build
> ```
>
> This builds both Svelte frontend AND Crystal binary with assets baked in. The `just nix-build` command updates a timestamp in `src/web/assets.cr` to force BakedFileSystem to pick up new frontend assets.
>
> If build fails, the task is NOT done. Fix all errors before marking the task as complete.
>
> **This rule is NON-NEGOTIABLE.** NEVER mark work as complete until `just nix-build` succeeds.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **COMPILE FIRST:** Run `just nix-build` - MUST succeed before proceeding
2. **Verify Work:** Run `nix develop . --command crystal spec` and `cd frontend && npm run test`
3. **Archival:** Use `/opsx:archive <name>` for all completed changes.
4. **PUSH TO REMOTE:**
    ```bash
    git pull --rebase
    git push
    git status  # MUST show "up to date with origin"
    ```
5. **Clean up:** Clear stashes, prune remote branches.
6. **Hand off:** Provide context for next session.

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds.
- NEVER stop before pushing - that leaves work stranded locally.
- NEVER say "ready to push when you are" - YOU must push.
- If push fails, resolve and retry until it succeeds.

## Building & Running QuickHeadlines

### The Golden Rule
**ALWAYS use `just nix-build` for building. This ensures BakedFileSystem picks up new frontend assets.**

### Quick Reference

```bash
# Build everything (RECOMMENDED)
just nix-build

# Start server
./bin/quickheadlines

# Run Crystal tests
nix develop . --command crystal spec

# Run frontend tests (Vitest)
cd frontend && npm run test
```

### Why `just nix-build`?

The `just nix-build` command:
1. Builds the Svelte frontend (`npm run build`)
2. Updates a timestamp in `src/web/assets.cr` to force BakedFileSystem recompilation
3. Rebuilds the Crystal binary with fresh assets baked in

**NEVER run `crystal build` directly** - it won't pick up frontend changes reliably.

### Common Issues & Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| Changes not visible in browser | BakedFileSystem not rebuilt | Run `just nix-build` |
| JS files returning 404 | Old binary running | Kill server, run `just nix-build`, restart |
| `undefined constant Code` in athena-routing | Crystal running outside nix develop | Use `just nix-build` |
| `crystal: command not found` | Crystal not in PATH | Use `just nix-build` |
| Feeds not updating after config changes | Stale database cache | Run `rm -rf ~/.cache/quickheadlines/` then restart server |
| Tab not persisting on refresh | Browser caching old JS | Hard refresh (Ctrl+Shift+R) or incognito |

### Environment Variables

The nix develop shell sets these automatically:
- `APP_ENV=development`
- `LD_LIBRARY_PATH` - Includes Crystal dependencies
- `PATH` - Includes crystal, shards, node, pnpm, make, openspec

### Understanding the Build Process

1. **Crystal Backend** (`src/quickheadlines.cr`)
   - Compiled with `crystal build --release`
   - Uses BakedFileSystem to embed frontend assets
   - Server listens on http://0.0.0.0:8080

2. **Svelte 5 Frontend** (`frontend/`)
   - Built with Vite to `frontend/dist/`
   - Uses `@sveltejs/adapter-static` with `fallback: 'index.html'` for SPA mode
   - Assets embedded in Crystal binary via BakedFileSystem

3. **Routes**
   - `/` - Main HTML (SPA entry point)
   - `/timeline` - Timeline page (SPA route)
   - `/_app/*` - SvelteKit immutable assets
   - `/api/*` - REST endpoints

## Key Learnings

### Svelte 5 Reactivity (CRITICAL)

**Function calls in templates are NOT reactive.** This is the #1 cause of UI not updating.

```svelte
<!-- WRONG - isDark() is not tracked -->
{#if isDark()}
  <p>Dark mode</p>
{/if}

<!-- CORRECT - property access IS tracked -->
{#if themeState.theme === 'dark'}
  <p>Dark mode</p>
{/if}
```

**Module-level state must be exported as objects, not reassigned primitives:**

```typescript
// WRONG - reassignment breaks reactivity when exported
export let theme = $state('light');

// CORRECT - object mutation preserves reactivity
export const themeState = $state({
  theme: 'light' as 'light' | 'dark',
  mounted: false
});
```

**Use `$effect` for side effects, not `onMount`:**

```svelte
<script>
  // Correct - runs on mount and when dependencies change
  $effect(() => {
    loadFeeds();
  });
  
  // Avoid - only runs once on mount
  onMount(() => {
    loadFeeds();
  });
</script>
```

### BakedFileSystem Rebuild Requirement

**CRITICAL:** The Crystal binary MUST be rebuilt after any Svelte build changes.

BakedFileSystem embeds files at **compile time**, not runtime. If you:
1. Run `npm run build` in frontend/
2. But don't rebuild the Crystal binary

The new JS/CSS files won't be served - you'll get 404s.

```bash
# Full rebuild workflow
cd frontend && npm run build
cp frontend/static/logo.svg frontend/dist/
cd ..
nix develop . --command crystal build --release src/quickheadlines.cr -o bin/quickheadlines
./bin/quickheadlines
```

**Force rebuild when assets change:**
```bash
touch src/web/assets.cr && nix develop . --command crystal build --release src/quickheadlines.cr -o bin/quickheadlines
```

### SvelteKit SPA Mode with adapter-static

Project uses SPA mode (client-side rendering only):

```javascript
// svelte.config.js
adapter: adapter({
  pages: 'dist',
  assets: 'dist',
  fallback: 'index.html',  // SPA fallback
  precompress: false,
  strict: true
})
```

```typescript
// src/routes/+layout.ts
export const prerender = true;
export const ssr = false;  // Disable SSR for SPA mode
```

### Duplicate Key Errors in #each Blocks

Always use unique keys in `#each` blocks. Composite keys work well:

```svelte
<!-- WRONG - duplicate URLs cause errors -->
{#each feeds as feed (feed.url)}

<!-- CORRECT - composite key ensures uniqueness -->
{#each feeds as feed, i (`feed-${i}`)}
{#each items as item, i (`${feed.url}-${i}`)}
```

### Tailwind Dark Mode

Tailwind is configured for `darkMode: 'class'`. Toggle dark mode by adding/removing `dark` class on `<html>`:

```typescript
document.documentElement.classList.toggle('dark', isDark);
```

```css
/* In templates - dark: prefix applies when dark class present */
<div class="bg-white dark:bg-slate-900">
```

### Timeline & Sorting

- **Timezone handling**: Times stored as UTC in DB, displayed in user's timezone
- **Infinite scroll pagination**:
  - Initial load: 35 items (fast page load)
  - Load More: 500 items per batch
  - Default timeline window: 14 days
- **Backend returns sorted items**: `pub_date DESC, id DESC`

### Clustering System

- **MinHash/LSH** for similarity detection
- **Threshold**: 0.75 similarity score required to cluster
- **Same-feed duplicate prevention**: Skip candidates from same feed_id

### Visual Regression Testing

- **Snapshot tests fail on UI changes**: Update with `npx playwright test --update-snapshots`
- **Commit snapshots**: Always commit updated snapshot files with design changes

### OpenSpec Workflow Notes

- **Change creation**: Use `openspec new change "name"` to create change directory
- **Manual spec sync**: When `openspec archive` times out, manually copy spec files
- **Tasks tracking**: Tasks.md uses `- [ ] 1.1 Description` format

## Quick Reference for Svelte Changes

```bash
# Build Svelte frontend
cd frontend && npm run build

# Check for build errors
cd frontend && npm run build 2>&1 | tail -20

# Preview production build locally
cd frontend && npm run preview
```

### Svelte MCP Autofix

After making any changes to Svelte files, you MUST run the Svelte MCP autofix to verify code quality:

1. Use the `svelte_svelte-autofixer` tool with your modified Svelte code
2. Fix any issues reported by the autofixer before completing the task
3. This ensures Svelte 5 best practices are followed

```typescript
// Example: Run autofix on your component code
svelte_svelte-autofixer({
  code: "<your component code>",
  desired_svelte_version: 5,
  filename: "YourComponent.svelte"
})
```

## Crystal Versioning & Platform Compatibility

### Crystal 1.18.2 Requirement

This project requires **Crystal 1.18.2** for FreeBSD compatibility. The Athena framework dependency requires this specific version.

**Why 1.18.2?**
- FreeBSD's package system only has Crystal 1.18.2 available
- Athena framework v0.21.x is compatible with Crystal 1.18.x
- Crystal 1.19.x deprecates `Time.monotonic` (warnings only, still compiles)

## Debug Mode & Favicon Troubleshooting

### Enabling Debug Mode

Add `debug: true` to your `feeds.yml` config file to enable verbose logging:

```yaml
refresh_minutes: 30
debug: true  # Enable verbose debug logging
item_limit: 20
```

### Common Favicon Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Favicon shows 404 in browser | Stale database cache | `rm -rf ~/.cache/quickheadlines/feed_cache.db*` |
| Favicon missing from UI | Feed redirect changed URL hash | Refresh feed to re-fetch favicon |
| Gray/fallback icon displayed | All fetching methods failed | Check debug output for network errors |

### Code Quality Tools

```bash
# Run Ameba linter (auto-fix issues)
nix develop . --command ameba --fix

# Check formatting only
nix develop . --command crystal tool format --check src/

# Run unreachable code check
nix develop . --command crystal tool unreachable src/quickheadlines.cr
```

## Svelte 5 Testing with Vitest

### Running Tests

```bash
# Run all tests once
cd frontend && npm run test

# Run tests in watch mode
cd frontend && npm run test:watch

# Run specific test file
cd frontend && npx vitest run src/lib/stores/theme.test.ts
```

### Test Structure

Tests are located in `frontend/src/lib/`:
- `stores/theme.test.ts` - Theme store unit tests
- `test/integration.test.ts` - API integration tests
- `test/setup.ts` - Test environment setup (jest-dom)

### Writing Component Tests

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import MyComponent from './MyComponent.svelte';

describe('MyComponent', () => {
  it('renders correctly', () => {
    render(MyComponent, { props: { title: 'Hello' } });
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });
});
```

### Mocking Browser APIs

```typescript
// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => { store[key] = value; },
    clear: () => { store = {}; }
  };
})();
Object.defineProperty(window, 'localStorage', { value: localStorageMock });

// Mock fetch
global.fetch = vi.fn();
```

### Troubleshooting Svelte 5 Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Theme not updating | Function calls in templates aren't tracked | Use property access: `themeState.theme` not `isDark()` |
| Timeline stuck loading | `$effect` runs before mount | Use `mounted` flag or `$effect(() => { if (!mounted) { mounted = true; loadData(); } })` |
| JS 404 errors | BakedFileSystem not rebuilt | `touch src/web/assets.cr && crystal build` |
| `$state` not reactive across modules | Exporting reassigned primitives | Export as const object: `export const state = $state({...})` |
| `$inspect` error in tests | Only works inside effects | Remove from module-level code |

### Key Svelte 5 Patterns

```svelte
<!-- WRONG: Function calls aren't tracked -->
{#if isDark()}

<!-- CORRECT: Property access is tracked -->
{#if themeState.theme === 'dark'}

<!-- WRONG: Exporting reassigned primitive -->
export let count = $state(0);

<!-- CORRECT: Export const object -->
export const state = $state({ count: 0 });

<!-- WRONG: $effect with async that needs to run once -->
$effect(() => { loadFeeds(); });

<!-- CORRECT: Guard with mounted flag -->
let mounted = $state(false);
$effect(() => {
  if (!mounted) {
    mounted = true;
    loadFeeds();
  }
});
```
