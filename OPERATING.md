# QuickHeadlines Operating Manual

> **Quick Reference:** `make help` for build targets, `make run` to start dev server, `make build` for production binary.

---

## 1. Development Environment

### Mandatory Shell
All commands must be executed via `nix develop --command <command>`. This ensures identical behavior across FreeBSD, Linux, and macOS.

```bash
# Enter development shell
nix develop --command bash

# Run commands directly
nix develop --command make run
nix develop --command crystal spec
nix develop --command elm-land build
```

### No Global Tools
Do not use system-installed Crystal, Elm, or Shards. If a tool is missing, it must be added to `flake.nix` rather than installed globally.

---

## 2. Project Structure

```
quickheadlines/
├── src/                    # Crystal backend source
│   ├── quickheadlines.cr   # Application entry point
│   ├── application.cr      # Athena framework setup
│   ├── config.cr           # Configuration loading (feeds.yml)
│   ├── fetcher.cr          # RSS/Atom feed fetching
│   ├── parser.cr           # XML parsing
│   ├── storage.cr          # SQLite cache
│   ├── api.cr              # API response types
│   ├── controllers/        # Athena controllers
│   ├── services/           # Athena services
│   ├── repositories/       # Athena repositories
│   ├── entities/           # Domain entities
│   └── dtos/               # Data transfer objects
├── ui/                     # Elm frontend source
│   ├── src/
│   │   ├── Main.elm        # Elm Land entry point
│   │   ├── Pages/          # Page modules
│   │   ├── Api.elm         # API client
│   │   └── Shared.elm      # Shared state
│   └── elm.js              # Compiled frontend
├── public/                 # Static assets
│   ├── elm.js              # Compiled frontend
│   ├── simple.js           # Simple JS fallback
│   └── vanilla-test.html   # Test page
├── feeds.yml               # Feed configuration
├── shard.yml               # Crystal dependencies
├── Makefile                # Build targets
└── README.md               # Project documentation
```

---

## 3. Build Commands

### Quick Reference

| Command | Description |
|---------|-------------|
| `make help` | Show all available targets |
| `make build` | Build release binary (default) |
| `make run` | Run in development mode |
| `make clean` | Remove build artifacts |
| `make rebuild` | Clean and rebuild everything |
| `make check-deps` | Verify required dependencies |
| `make elm-install` | Install Elm tools |
| `make elm-build` | Compile Elm to JavaScript |
| `make elm-format` | Format Elm source files |
| `make elm-validate` | Validate Elm syntax |
| `make test-frontend` | Run Playwright frontend tests |

### Development Workflow

```bash
# 1. Enter development shell
nix develop --command bash

# 2. Check dependencies
make check-deps

# 3. Run in development mode (auto-recompiles Crystal, rebuilds Elm on changes)
make run

# Or for faster iteration, run frontend and backend separately:
make elm-build  # Compile Elm
crystal run src/quickheadlines.cr -- config=feeds.yml  # Run backend
```

### Production Build

```bash
# Build release binary
make build

# Output location: bin/quickheadlines

# Run the binary
./bin/quickheadlines

# Default port: 3030
# Config file: feeds.yml (must be in same directory)
```

---

## 4. Configuration

### feeds.yml Structure

```yaml
# Global settings
refresh_minutes: 30        # Refresh interval in minutes
item_limit: 20             # Items per feed (default: 100)
server_port: 3030          # HTTP server port
page_title: "Quick Headlines"
cache_retention_hours: 168 # Cache retention (1 week)

# HTTP client configuration (optional)
http_client:
  timeout: 30              # Read timeout in seconds
  connect_timeout: 10      # Connection timeout in seconds
  user_agent: "QuickHeadlines/0.3"

# Tab configuration
tabs:
  - name: "Tech"
    feeds:
      - title: "Hacker News"
        url: "https://news.ycombinator.com/rss"
        header_color: "orange"  # Optional
        item_limit: 20          # Override global limit
        max_retries: 5          # Retry attempts
        retry_delay: 3          # Delay between retries
        timeout: 45             # Request timeout
      - title: "Tech Radar"
        url: "https://www.techradar.com/feeds.xml"

# Software releases tracking
  - name: "Dev"
    software_releases:
      title: "Project Updates"
      repos:
        - "crystal-lang/crystal"     # GitHub (default)
        - "inkscape/inkscape:gl"     # GitLab
        - "supercell/luce:cb"        # Codeberg
```

### Cache Directory

The cache directory location is determined by:
1. `QUICKHEADLINES_CACHE_DIR` environment variable
2. `cache_dir` in `feeds.yml`
3. `$XDG_CACHE_HOME/quickheadlines` (default on Linux)
4. `./cache` in current directory

---

## 5. Testing

### Crystal Tests
```bash
nix develop --command crystal spec
```

### Elm Validation
```bash
nix develop --command elm make src/Main.elm --output=/dev/null
```

### Frontend Tests (Playwright)
```bash
nix develop --command make test-frontend
```

---

## 6. Technical Standards

### Backend (Crystal + Athena)
- **Framework:** Crystal with Athena framework
- **Data Handling:** Strictly typed DTOs with `JSON::Serializable`
- **Database:** SQLite via `crystal-sqlite3`
- **Serialization:** Use `Athena::Serializer`, never manually stringify JSON
- **Error Handling:** Use `Result(T, E)` patterns, never let server crash on malformed RSS

### Frontend (Elm Land + elm-ui)
- **Framework:** Elm Land with `mdgriffith/elm-ui`
- **Styling:** Use `Element` primitives only
- **Forbidden:** `Html`, `Html.Attributes`, `class` tags, Tailwind/CSS
- **State:** Use Elm Land's file-based routing and `Effect` pattern

### Architecture
- **Decoupling:** Backend is JSON API, frontend is static SPA
- **Independence:** Must remain independent for future backend porting

---

## 7. Code Quality Rules

### Type Safety
- No `as_any` or `JSON.parse` into untyped hashes
- Use DTOs for everything

### Dependencies
- Every new dependency is a liability
- Prefer standard library or core framework features first
- Any new Shard or Elm package requires a "Why" note in PR

### Documentation
- Changes adding new dependencies require brief ADR notes

---

## 8. Issue Tracking

### Beads Workflow
```bash
nix develop --command bd ready              # Find available work
nix develop --command bd show <id>          # View issue details
nix develop --command bd update <id> --status in_progress  # Claim work
nix develop --command bd close <id>         # Complete work
nix develop --command bd sync               # Sync with git
```

### Double-Entry Rule
- Every Work Package (WP) in Spec Kitty MUST have a corresponding **Epic** in Beads
- Every sub-task must be created as a **Task** in Beads linked to its parent Epic
- Task is "Done" when Beads issue is closed (`bd close`) AND Spec Kitty task is checked off

---

## 9. Common Tasks

### Add a New Feed
1. Edit `feeds.yml`:
   ```yaml
   tabs:
     - name: "Category"
       feeds:
         - title: "New Feed"
           url: "https://example.com/feed.xml"
   ```
2. Restart the application

### Change Item Limit
```yaml
# Global (affects all feeds)
item_limit: 30

# Per-feed (overrides global)
tabs:
  - name: "Tech"
    feeds:
      - title: "Hacker News"
        url: "https://news.ycombinator.com/rss"
        item_limit: 50
```

### Modify Frontend
1. Edit Elm files in `ui/src/`
2. Run `make elm-build` to recompile
3. Refresh browser to see changes

### Debug Feed Fetching
```bash
# Run with verbose logging
nix develop --command crystal run src/quickheadlines.cr -- --verbose
```

---

## 10. Troubleshooting

### Crystal Build Fails
```bash
# Ensure dependencies are installed
nix develop --command shards install

# Clean and rebuild
make rebuild
```

### Elm Compilation Fails
```bash
# Install Elm tools
make elm-install

# Check for syntax errors
make elm-validate
```

### Elm UI Not Displaying
- Check browser console for JavaScript errors
- Ensure `public/elm.js` exists after `make elm-build`
- Verify `public/` directory is accessible

### Cache Issues
```bash
# Clear cache directory
rm -rf ~/.cache/quickheadlines/

# Or set custom cache location
export QUICKHEADLINES_CACHE_DIR=/tmp/quickheadlines
```

---

## 11. Dependencies

### Required (Auto-installed via Nix)
- **Crystal:** >= 1.18.2 (version 1.19.1 used)
- **Shards:** Crystal package manager
- **SQLite3:** Development libraries
- **OpenSSL:** Development libraries
- **Node.js/npm:** For Elm tools and Tailwind

### Platform-Specific

**Ubuntu/Debian:**
```bash
sudo apt-get install libsqlite3-dev libssl-dev libmagic-dev
```

**Fedora/RHEL:**
```bash
sudo dnf install sqlite-devel openssl-devel file-devel
```

**Arch Linux:**
```bash
sudo pacman -S crystal sqlite openssl file
```

**macOS:**
```bash
brew install crystal openssl@3 libmagic
```

**FreeBSD:**
```bash
pkg install crystal shards sqlite3 openssl libmagic llvm19
```
