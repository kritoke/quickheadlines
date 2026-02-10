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
> This project is a Nix Spoke. You are running inside a persistent Hub, but the project-specific tools (Crystal 1.18.2, Elm, Shards) are isolated.
 > Rule: For ANY shell command execution (compiling, testing, formatting), you MUST run commands inside the nix devshell. Prefer either: (A) call `make` targets from inside the devshell (recommended), or (B) use the devshell `--command` with the working-directory semantics your tooling supports.
 > - Recommended: `nix develop . --command make run` or `nix develop . --command make elm-build`
 > - Avoid: `nix develop . --command "cd ui && elm make ..."` because some wrappers treat the whole quoted string as a program path and fail with posix_spawn/ENOENT. If you must run an exact program in a subdirectory, use the devshell's workdir parameter (e.g., `workdir=ui`) or run `make` targets that encapsulate directory changes.
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

> MANDATORY COMPILATION CHECK:
> Before EVER saying a task is "done", "complete", "ready for review", or marking it as finished, you MUST compile the program and verify it builds successfully.
>
> **Required command:**
> ```bash
> nix develop . --command crystal build src/quickheadlines.cr
> ```
>
> If compilation fails, the task is NOT done. Fix all compilation errors before marking the task as complete.
>
> **This rule is NON-NEGOTIABLE.** Multiple instances of agents claiming tasks were "done" while the code didn't compile have caused issues. NEVER mark work as complete until `crystal build` succeeds.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **COMPILE FIRST:** Run `nix develop . --command crystal build src/quickheadlines.cr` - MUST succeed before proceeding
2. **Verify Work:** Run `nix develop . --command npx playwright test` and any relevant Crystal specs.
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
**ALWAYS use `nix develop . --command` prefix for any Crystal, Elm, or Shards command.**

This sets up the correct `LD_LIBRARY_PATH` for Crystal's dependencies (boehmgc, libevent, pcre2, etc.). Without it, you'll get cryptic errors like `undefined constant Code` in athena-routing.

### Quick Reference

Prefer running Makefile targets inside the devshell; they encapsulate environment setup and directory context.

```bash
# Start development server (recommended)
nix develop . --command make run

# Build production Elm bundle (recommended)
nix develop . --command make elm-build

# Run Crystal tests
nix develop . --command crystal spec

# Rebuild Elm frontend manually (avoid embedding `cd` inside --command)
# Good: use the nix devshell workdir feature if available, or run make:
#   workdir=ui nix develop . --command 'elm make src/Main.elm --optimize --output=../public/elm.js'
# Better: use make
nix develop . --command make elm-build

# Install/update dependencies
nix develop . --command shards install

# Format Elm code
# workdir=ui nix develop . --command elm-format src/
# or using make wrapper:
nix develop . --command make elm-format

# Run Playwright tests
nix develop . --command npx playwright test
```

### Common Issues & Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| `undefined constant Code` in athena-routing | Crystal running outside nix develop | Always prefix with `nix develop . --command` |
| `crystal: command not found` | Crystal not in PATH | Use full path `/home/kritoke/.local/bin/crystal` or nix develop |
| `libgc.so.1 not found` | Missing library path | Run through nix develop (sets LD_LIBRARY_PATH) |
| Make command not found | make not in PATH | nix develop provides gnumake |
| Feeds not updating after config changes | Stale database cache | Run `rm -rf ~/.cache/quickheadlines/feed_cache.db*` then restart server |

### Environment Variables

The nix develop shell sets these automatically:
- `APP_ENV=development`
- `LD_LIBRARY_PATH` - Includes Crystal dependencies
- `PATH` - Includes crystal, shards, elm, make, openspec

### Understanding the Build Process

1. **Crystal Backend** (`src/quickheadlines.cr`)
   - Compiled on-the-fly with `crystal run`
   - Shards installed in `lib/`
   - Server listens on http://0.0.0.0:8080

2. **Elm Frontend** (`ui/src/Main.elm`)
   - Compiled to `public/elm.js`
   - Served at `/elm.js` route
   - Inlined CSS in `views/index.html` for development

3. **Routes**
   - `/` - Main HTML with inlined CSS
   - `/elm.js` - Compiled Elm bundle
   - `/api/*` - REST endpoints

## Key Learnings

### JavaScript/CSS Debugging

- **Console logging for timing issues**: When code runs before elements exist, add `console.log` to verify execution order and element presence
- **CSS execution order matters**: Inline styles (`style=""`) override CSS classes. Use `!important` in CSS to override inline styles from JavaScript/Elm
- **Function scope**: Functions defined inside `DOMContentLoaded` callbacks aren't accessible outside. Assign to `window.functionName` to make them globally available
- **Timing fixups**: Run code at multiple intervals (500ms, 1500ms, 3000ms) to catch elements that load at different times

### Color Handling

- **YIQ Formula for text readability**: Calculate contrast color from background using `((r * 299) + (g * 587) + (b * 114)) / 1000`. If result >= 128, use dark text; otherwise use light text
- **Color thief limitations**: Favicons that fail to load (404s, broken images) cause color extraction to fail, leaving headers with default/invisible colors
- **Elm color classes**: Elm generates dynamic classes like `fc-148-163-184` for inline colors. These can be overridden with CSS targeting the element directly
- **Fixing unreadable headers**: Strip inline styles with `element.style.cssText = ''` then apply readable colors using YIQ

### Horizontal Scrollbars

- **Prevent with `overflow-x: hidden`**: Add to `html`, `body`, `#app`, and scroll containers to prevent horizontal overflow
- **Use `!important`**: `overflow-x: hidden !important` ensures the rule takes precedence over other CSS

### Clustering System

- **How it works**: Uses MinHash/LSH (Locality Sensitive Hashing) for efficient similarity detection
  - MinHash computes signatures that preserve Jaccard similarity
  - LSH bands bucket similar signatures for fast candidate retrieval
  - Threshold: 0.75 similarity score required to cluster
  - Minimum 5 words required for clustering eligibility

- **Same-feed duplicate prevention**: Critical to skip candidates from the same feed
  - Without this, identical articles from re-fetches get clustered together
  - Pass `feed_id` to `compute_cluster_for_item` and skip if candidate has same feed_id
  - Added `get_item_feed_id` and `get_feed_id` methods to storage.cr

- **Database schema**:
  - `items.cluster_id` - Points to representative item ID (or self if singleton)
  - Representative = lowest ID in cluster (deterministic)
  - `lsh_bands` table - Stores band hashes for LSH lookups
  - `item_signatures` table - Stores MinHash signatures

- **Clustering verification query**:
  ```sql
  SELECT cluster_id, COUNT(*) as cnt FROM items GROUP BY cluster_id HAVING cnt > 1
  ```

### Timeline & Sorting

- **Timezone handling**: Elm frontend uses `Time.customZone -360 []` for US Central (CST/CDT)
  - Change in `ui/src/Application.elm:84`
  - Times stored as UTC in DB, displayed in user's timezone

- **Day grouping**: Elm groups items by date, displays newest day first
  - `groupClustersByDay` in Timeline.elm sorts days newest-first
  - Items within each day sorted newest-first

- **Infinite scroll pagination**:
  - Initial load: 35 items (fast page load)
  - Load More: 500 items per batch
  - Default timeline window: 14 days (`cache_retention_hours: 336` in feeds.yml)
  - NO resort on merge - prevents scroll position jumps
  - Backend returns already-sorted items (pub_date DESC, id DESC)

- **Common issues**:
  - Items split across pages = clusters appear incomplete
  - Increase `cache_retention_hours` or `db_fetch_limit` to see more clusters
  - `?limit=1000` query param overrides defaults

### When NOT to Fix

- Leave working features alone. If color thief produces readable results, don't override it with aggressive fixes
- Simple is better. Over-engineering causes new bugs (like breaking previously working colors)

### Elm UI Styling Best Practices

- **Keep styles in Elm**: Use Elm UI attributes for all styling (Background, Font, Border, padding). This avoids CSS specificity wars and keeps styles theme-aware.
- **Minimal CSS**: Only use CSS for `@font-face`, scrollbar styling, and pseudo-elements that Elm can't express. Everything else belongs in Elm.
- **Avoid `htmlAttribute (HA.style ...)` for core styles**: Use dedicated Elm attributes (e.g., `Background.color`, `Border.rounded`) instead of inline style strings. This keeps styles centralized and themeable.
- **Theme tokens over hardcoded values**: Add tokens to `Theme.elm` for colors, surfaces, and backgrounds. This ensures dark/light mode consistency without scattered conditionals.

### Typography Helpers Pattern

- **Centralized responsive typography**: Create helper functions in `ThemeTypography.elm` (e.g., `hero`, `dayHeader`) that return responsive font attributes based on `Breakpoint`.
- **Pattern example**:
  ```elm
  hero : Breakpoint -> List (Attribute msg)
  hero breakpoint =
      let
          size =
              case breakpoint of
                  VeryNarrowBreakpoint -> 20
                  MobileBreakpoint -> 20
                  TabletBreakpoint -> 28
                  DesktopBreakpoint -> 36
      in
      [ Font.size size, Font.semiBold, Font.letterSpacing 0.6 ]
  ```
- **Use `Ty.hero breakpoint` in views**: Pass the current breakpoint to get the right size. Keeps all size logic in one place.

### Visual Regression Testing

- **Snapshot tests fail on UI changes**: When modifying styles, visual regression tests (`timeline-favicon.spec.ts`) will fail with pixel differences. This is expected.
- **Update snapshots after design changes**:
  ```bash
  npx playwright test --update-snapshots
  ```
- **Commit snapshots**: Always commit updated snapshot files with the design change so tests pass for future commits.
- **Minor pixel differences are OK**: Small height/width changes (8-16px) are normal when adding padding or changing fonts. Update snapshots rather than debugging pixel-perfect matches.

### Font Integration

- **Self-host variable fonts**: Download WOFF2 files to `public/fonts/` and serve locally. This avoids CDN dependencies and ensures offline support.
- **Pattern for adding fonts**:
  1. Download font to `public/fonts/<name>.woff2`
  2. Add `@font-face` in `views/index.html` `<style>` block
  3. Use in Elm: `Font.family [ Font.name "Font Name", Font.system ]`
- **Variable fonts simplify weights**: Use `font-weight: 100 900` in CSS and `Font.semiBold` (600) in Elm for clean weight handling.
- **Font fallback stack**: Always include system fonts after custom fonts: `Font.family [ Font.name "Inter var", Font.system ]` where `Font.system` expands to `-apple-system, BlinkMacSystemFont, ...`

### OpenSpec Workflow Notes

- **Change creation**: Use `openspec new change "name"` to create change directory with proposal/design/specs/tasks.
- **Manual spec sync**: When `openspec archive` times out or fails, manually copy spec files:
  ```bash
  cp openspec/changes/<change>/specs/<cap>/spec.md openspec/specs/<cap>/spec.md
  ```
- **Tasks tracking**: Tasks.md uses `- [ ] 1.1 Description` format. Check off as you complete. OpenSpec reads this format during verification.

### Quick Reference for Elm Changes

```bash
# Rebuild Elm after changes (preferred: use Makefile target inside devshell)
nix develop . --command make elm-build

# Alternatively, run Elm from the ui/ directory using the devshell workdir
# workdir=ui nix develop . --command 'elm make src/Main.elm --optimize --output=../public/elm.js'

# Format Elm code (use workdir or make wrapper)
# workdir=ui nix develop . --command elm-format src/
nix develop . --command make elm-format

# Check Elm compiler errors (short): run from ui/ via workdir
# workdir=ui nix develop . --command 'elm make src/Main.elm 2>&1 | head -50'
```

## Crystal Versioning & Platform Compatibility

### Crystal 1.18.2 Requirement

This project requires **Crystal 1.18.2** for FreeBSD compatibility. The Athena framework dependency requires this specific version.

**Why 1.18.2?**
- FreeBSD's package system only has Crystal 1.18.2 available
- Athena framework v0.21.x is compatible with Crystal 1.18.x
- Crystal 1.19.x deprecates `Time.monotonic` (warnings only, still compiles)

**GitHub Actions Configuration:**
- Must use `crystal: 1.18.2` (not `latest`) in all workflow files
- Both `crystal-lang/install-crystal@v1` and `crystal-lang/setup-crystal@v2` support version pinning
- CI jobs for Ubuntu, macOS, and tests.yml all use 1.18.2

### Platform-Specific Crystal Handling

| Platform | Installation | Makefile Behavior |
|----------|--------------|-------------------|
| Linux | `crystal-lang/install-crystal@v1` with version | Downloads from official tarball |
| macOS | Homebrew or GitHub Action | Uses `which crystal` (system-installed) |
| FreeBSD | `pkg install crystal` | Uses system Crystal directly |

**macOS-specific fix:**
- The Makefile previously tried to download Crystal from source on macOS
- This failed because `CRYSTAL_TARBALL` and `CRYSTAL_URL` were undefined
- Solution: macOS now uses system-installed Crystal via `which crystal`
- CI macOS job uses `crystal-lang/install-crystal@v1` to install to PATH

### Time.monotonic Deprecation

Crystal 1.19.x warns about `Time.monotonic` deprecation, recommending `Time.instant` instead:

```
Warning: Deprecated Time.monotonic. Use `Time.instant` instead.
```

**Current policy:** Keep `Time.monotonic` for FreeBSD compatibility. The warnings are harmless and the code compiles and runs correctly on all platforms.

**If FreeBSD support is dropped in the future**, migrate to `Time.instant`:
```crystal
# Before
start_time = Time.monotonic
elapsed = (Time.monotonic - start_time).total_seconds

# After
start_time = Time.instant
elapsed = (Time.instant - start_time).total_seconds
```

### Makefile System Crystal Discovery

**Problem:** GitHub Actions uses `crystal-lang/install-crystal@v1` which installs Crystal to system PATH (`/usr/local/bin/crystal`), but the Makefile only checked for `bin/crystal` and tried to download from source. This failed because `CRYSTAL_TARBALL` and `CRYSTAL_URL` were undefined.

**Solution:** Added system Crystal detection to Makefile:
```makefile
FINAL_CRYSTAL := $(shell if command -v crystal >/dev/null 2>&1; then echo "crystal"; else echo "$(CRYSTAL)"; fi)
```

**Key pattern:**
- Check `which crystal` or `command -v crystal` first for system-installed Crystal
- Fall back to project `bin/crystal` only if system Crystal not found
- This allows GitHub Actions to work without modifying the Makefile per-runner

**Platform precedence:**
1. Linux CI: Uses system crystal from `crystal-lang/install-crystal`
2. macOS: Uses system crystal from Homebrew or `crystal-lang/install-crystal`
3. FreeBSD: Falls back to `download-crystal` if no system crystal
4. Local development: Uses `bin/crystal` (nix or manually managed)

## Debug Mode & Favicon Troubleshooting

### Enabling Debug Mode

Add `debug: true` to your `feeds.yml` config file to enable verbose logging:

```yaml
refresh_minutes: 30
debug: true  # Enable verbose debug logging
item_limit: 20
...
```

Debug mode outputs detailed information about:
- Favicon fetching attempts and successes
- Redirect chains for feeds and favicons
- HTTP status codes (404, 403, etc.)
- Fallback chain usage (HTML parsing, Google favicon service)
- Cache hits and misses

### Testing Debug Mode

```bash
# Clear stale cache before testing
rm -rf ~/.cache/quickheadlines/feed_cache.db*

# Start server with debug mode
nix develop . --command make run

# In another terminal, check feeds with favicons
curl -s "http://127.0.0.1:8080/api/feeds" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for feed in data.get('feeds', []):
    title = feed.get('title', '')
    fav = feed.get('favicon', 'MISSING')
    print(f'{title}: favicon={fav}')
"
```

### Favicon Fetching Debug Output

When debug mode is enabled, you'll see output like:
```
[DEBUG] Fetching favicon: https://www.google.com/s2/favicons?domain=www.nasa.gov&sz=64
[DEBUG] Favicon redirect 1: https://www.nasa.gov/favicon.ico
[DEBUG] Favicon fetched: https://www.nasa.gov/favicon.ico, size=4286, type=image/x-icon
[DEBUG] Favicon saved: /favicons/725ba8bbaf1ef9bd.ico
[DEBUG] Google fallback for: https://www.nasa.gov/rss/dyn/breaking_news.rss
```

### Common Favicon Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Favicon shows 404 in browser | Stale database cache | `rm -rf ~/.cache/quickheadlines/feed_cache.db*` |
| Favicon missing from UI | Feed redirect changed URL hash | Refresh feed to re-fetch favicon |
| Gray/fallback icon displayed | All fetching methods failed | Check debug output for network errors |
| Favicon file exists but 404 | Server serving from wrong directory | Ensure running from project root |
| 198-byte gray placeholder | Site returns "not found" icon | System auto-retries with larger Google favicon (256px) |
| Feed returns bot protection | Site blocks automated access | May need manual favicon or feed removal |

### Gray Placeholder Detection

The system detects 198-byte favicon files (the common "not found" size from both sites and Google's service) and automatically:
1. Skips saving the gray placeholder
2. For Google favicon URLs: retries with larger size (256px instead of 64px)
3. For direct site favicons: triggers Google fallback

### Sites That Block Favicon Fetching

Some sites use bot protection that blocks favicon extraction:
- **AI News** (artificialintelligence-news.com): Returns bot protection page
- **OpenAI** (openai.com): Blocks HTML parsing with 403
- **Science.org**: Blocks HTML parsing with 403
- **ItsFOSS**: Blocks HTML parsing with 403

For these sites, the Google fallback will still work but may return generic icons.

### HTTPS First for HTTP URLs

The codebase now automatically upgrades HTTP URLs to HTTPS for security:

```yaml
# Before (HTTP)
- url: "http://example.com/feed"

# After (automatic upgrade)
# The system tries https://example.com/feed first
# Falls back to http:// only if HTTPS fails
```

This applies to:
- Feed URL fetching
- Favicon URL fetching
- HTML parsing for favicon links

### Checking Favicon Status

```bash
# Check if a specific favicon is serving
curl -I "http://127.0.0.1:8080/favicons/<hash>.png"

# Verify all favicons from feeds
bash scripts/check_favicons.sh

# Check feeds.json for missing favicons
curl -s "http://127.0.0.1:8080/api/feeds" | grep -o '"favicon":"[^"]*"' | sort | uniq -c
```

### Debugging Missing Favicons

1. Enable debug mode in feeds.yml
2. Clear cache: `rm -rf ~/.cache/quickheadlines/feed_cache.db*`
3. Restart server
4. Watch console output for favicon fetch attempts
5. Check if the feed's site_link is accessible
6. Verify the site's homepage has a favicon link tag

```bash
# Test if a site's homepage returns a favicon
curl -s "https://www.nasa.gov/" | grep -i "link.*icon"
curl -sI "https://www.nasa.gov/favicon.ico"
```

### Code Quality Tools

```bash
# Run Ameba linter (auto-fix issues)
nix develop . --command ameba --fix

# Check formatting only
nix develop . --command crystal tool format --check src/

# Run unreachable code check
nix develop . --command crystal tool unreachable src/quickheadlines.cr
```

---

## Skill Loading (IMPORTANT)

**Skills are NOT loaded automatically.** You must load them at the start of each session.

### Available Skills

| Skill | Location | Purpose |
|-------|----------|----------|
| `crystal` | `/home/kritoke/.kilocode/skills/crystal/` | Crystal concurrency, Fiber/Channel patterns, JSON::Serializable |
| `elm` | `/home/kritoke/.kilocode/skills/elm/` | Elm architecture, TEA patterns |
| `openspec` | `/home/kritoke/.config/opencode/skills/openspec/` | Architecture standards, OpenSpec workflow |

### How to Load Skills

At the start of EVERY session, run:

```bash
# Load Crystal skill (for backend development)
read /workspaces/aiworkflow/skills/crystal/CRYSTAL_SKILLS.md

# Load Elm skill (for frontend development)
read /workspaces/aiworkflow/skills/elm/ELM_SKILLS.md

# Load OpenSpec skill (always needed)
read /home/kritoke/.config/opencode/skills/openspec/openspec/project.md
```

### For This Project

QuickHeadlines uses both Crystal (backend) and Mint (frontend). At the start of each session, you MUST:

1. **Load Crystal skill** - For feed processing, clustering, API endpoints
   ```bash
   read /workspaces/aiworkflow/skills/crystal/CRYSTAL_SKILLS.md
   ```

2. **Load Elm skill** - For understanding legacy Elm code (ui/ directory)
   ```bash
   read /workspaces/aiworkflow/skills/elm/ELM_SKILLS.md
   ```

### Quick Reference

**Crystal concurrency patterns to use:**
- Worker-Pool for feed refresh: `Channel(FeedTask).new(100)` with multiple workers
- Fan-In for collecting results: Use `WaitGroup` or result channel
- "Zero-Any Rule": Use `JSON::Serializable::Strict` only

**Elm patterns to follow:**
- TEA architecture (Model, Update, View)
- No architectural comments - keep code clean

### What Happens If You Don't Load Skills

Without loading skills, you will:
- ❌ Miss Crystal concurrency best practices
- ❌ Use `Any` types instead of strict JSON
- ❌ Write imperative code instead of functional
- ❌ Forget about Fiber/Channel patterns

### Add to Your Session Startup

When starting a new session, begin with:

```
I will now load the Crystal and Elm skills for this QuickHeadlines project.

read /workspaces/aiworkflow/skills/crystal/CRYSTAL_SKILLS.md
read /workspaces/aiworkflow/skills/elm/ELM_SKILLS.md

Skills loaded. Ready to work on Crystal backend and Mint frontend.
```

This ensures you apply the knowledge from:
- `/workspaces/aiworkflow/skills/crystal/CRYSTAL_SKILLS.md`
- `/workspaces/aiworkflow/skills/elm/ELM_SKILLS.md`
