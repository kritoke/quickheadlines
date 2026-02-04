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
> This project is a Nix Spoke. You are running inside a persistent Hub, but the project-specific tools (Crystal 1.19.1, Elm, Shards) are isolated.
> Rule: For ANY shell command execution (compiling, testing, formatting), you MUST prefix the command with `nix develop . --command`.
> - Incorrect: `crystal spec`
> - Correct: `nix develop . --command crystal spec`
> - Incorrect: `shards install`
> - Correct: `nix develop . --command shards install`

### 2. The Library/Linker Workaround

Because Crystal 1.19.1 is manually derived and requires specific library paths:

> Library Path Handling:
> If a command fails with a "library not found" error (e.g., libgc.so.1 or libevent), do not attempt to install packages via apt. Instead, verify that the command is being run through the nix develop wrapper, as the flake handles the LD_LIBRARY_PATH internally.

### 3. OpenSpec Discipline

> Task Discipline:
> Agents must create a Change Proposal (`/opsx:new`) before writing code. Archival (`/opsx:archive`) is mandatory for all completed tasks to merge changes into the permanent specs in `openspec/specs/`.

### 4. Why This Is Necessary

OpenCode agents often try to be "helpful" by running commands directly in the shell they find themselves in. In this setup:
- The Base Shell is your "Hub" (which has Go, Node, but NOT Crystal 1.19.1)
- The Sub-Shell created by `nix develop . --command` has the "Spoke" tools

If you don't use the prefix, you will get a `command not found: crystal` error, even though the file is right there in the project.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Verify Work:** Run `nix develop . --command npx playwright test` and any relevant Crystal specs.
2. **Archival:** Use `/opsx:archive <name>` for all completed changes.
3. **PUSH TO REMOTE:**
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
4. **Clean up:** Clear stashes, prune remote branches.
5. **Hand off:** Provide context for next session.

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

```bash
# Start development server (runs on port 8080)
nix develop . --command make run

# Run Crystal tests
nix develop . --command crystal spec

# Rebuild Elm frontend (after UI changes)
nix develop . --command cd ui && elm make src/Main.elm --output=../public/elm.js

# Install/update dependencies
nix develop . --command shards install

# Format Elm code
nix develop . --command cd ui && elm-format src/

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

### When NOT to Fix

- Leave working features alone. If color thief produces readable results, don't override it with aggressive fixes
- Simple is better. Over-engineering causes new bugs (like breaking previously working colors)


