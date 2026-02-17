# QuickHeadlines Operating Manual

> **Quick Reference:** `just help` for build targets, `just nix-build` to build, `./bin/quickheadlines` to run.

---

## 1. Development Environment

### Mandatory Shell
All commands must be executed via `nix develop --command <command>` or using `just` recipes. This ensures identical behavior across FreeBSD, Linux, and macOS.

```bash
# Enter development shell
nix develop --command bash

# Run commands directly
nix develop --command crystal spec
just nix-build
```

### No Global Tools
Do not use system-installed Crystal or Shards. If a tool is missing, it must be added to `flake.nix` rather than installed globally.

---

## 2. Project Structure

```
quickheadlines/
├── src/                    # Crystal backend source
│   ├── quickheadlines.cr   # Application entry point
│   ├── config.cr           # Configuration loading (feeds.yml)
│   ├── fetcher.cr          # RSS/Atom feed fetching
│   ├── parser.cr           # XML parsing
│   ├── storage.cr          # SQLite cache
│   ├── api.cr              # API response types
│   ├── controllers/        # Athena controllers
│   ├── services/           # Athena services
│   └── web/                # Static file serving
├── frontend/               # Svelte 5 frontend
│   ├── src/
│   │   ├── routes/         # SvelteKit routes
│   │   ├── lib/            # Components and stores
│   │   └── app.html        # HTML template
│   ├── dist/               # Built frontend (embedded in binary)
│   └── package.json        # Node dependencies
├── bin/                    # Compiled binaries
├── feeds.yml               # Feed configuration
├── shard.yml               # Crystal dependencies
├── justfile                # Build recipes
└── README.md               # Project documentation
```

---

## 3. Build Commands

### Quick Reference

| Command | Description |
|---------|-------------|
| `just nix-build` | Build production binary (RECOMMENDED) |
| `just build` | Build using system crystal |
| `just run` | Run in development mode |
| `just clean` | Remove build artifacts |
| `just rebuild` | Clean and rebuild everything |
| `just check-deps` | Verify required dependencies |
| `just test-frontend` | Run Vitest frontend tests |
| `just help` | Show all available targets |

### Development Workflow

```bash
# 1. Build everything
just nix-build

# 2. Run the server
./bin/quickheadlines

# 3. For frontend development
cd frontend && npm run dev
```

### Production Build

```bash
# Build release binary
just nix-build

# Output location: bin/quickheadlines

# Run the binary
./bin/quickheadlines

# Default port: 8080
# Config file: feeds.yml (must be in same directory)
```

---

## 4. Configuration

### feeds.yml Structure

```yaml
# Global settings
refresh_minutes: 30        # Refresh interval in minutes
item_limit: 20             # Items per feed (default: 100)
server_port: 8080          # HTTP server port
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

### Clustering Configuration

The clustering feature uses MinHash/LSH to group similar stories across feeds. Configuration is optional - defaults are designed to work well out of the box.

```yaml
# Clustering configuration (optional)
clustering:
  enabled: true                    # Enable automatic clustering (default: true)
  schedule_minutes: 60             # Run clustering every N minutes (default: 60)
  run_on_startup: true            # Run clustering on startup (default: true)
  max_items: 5000                 # Max items per clustering run (default: nil = use db_fetch_limit)
  threshold: 0.75                 # Similarity threshold 0.0-1.0 (default: 0.75)
```

#### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | Bool | true | Enable/disable automatic clustering |
| `schedule_minutes` | Int32 | 60 | How often to run clustering (in minutes) |
| `run_on_startup` | Bool | true | Run clustering when the application starts |
| `max_items` | Int32? | nil | Max items to process per run (nil = use `db_fetch_limit`) |
| `threshold` | Float64 | 0.75 | Similarity threshold (higher = stricter matching) |

#### Tuning the Threshold

- **Higher (0.8-0.9):** Stricter matching, fewer but more accurate clusters
- **Lower (0.5-0.7):** More aggressive clustering, may group unrelated stories
- **Default (0.75):** Balanced - works well for news headlines

#### Manual Clustering

You can manually trigger clustering via the API:

```bash
# Trigger clustering on uncategorized items
curl -X POST http://127.0.0.1:8080/api/run-clustering

# Clear and re-cluster all items
curl -X POST http://127.0.0.1:8080/api/recluster
```

#### Debugging Clustering

Enable debug output to see clustering decisions:

```bash
DEBUG_CLUSTERING=1 ./bin/quickheadlines
```

---

## 5. Testing

### Crystal Tests
```bash
nix develop . --command crystal spec
```

### Frontend Tests (Vitest)
```bash
cd frontend && npm run test
```

---

## 6. Technical Standards

### Backend (Crystal + Athena)
- **Framework:** Crystal with Athena framework
- **Data Handling:** Strictly typed DTOs with `JSON::Serializable`
- **Database:** SQLite via `crystal-sqlite3`
- **Serialization:** Use `Athena::Serializer`, never manually stringify JSON
- **Error Handling:** Use `Result(T, E)` patterns, never let server crash on malformed RSS

### Frontend (Svelte 5 + Tailwind)
- **Framework:** Svelte 5 with SvelteKit
- **Styling:** Tailwind CSS
- **Build:** Vite with `@sveltejs/adapter-static` for SPA mode
- **State:** Use `$state`, `$derived`, `$effect` runes

### Architecture
- **Decoupling:** Backend is JSON API, frontend is static SPA
- **Independence:** Must remain independent for future backend porting
- **Embedded:** Frontend assets are baked into the binary via BakedFileSystem

---

## 7. Code Quality Rules

### Type Safety
- No `as_any` or `JSON.parse` into untyped hashes
- Use DTOs for everything

### Dependencies

Required (Auto-installed via Nix)
- **Crystal:** >= 1.18.2
- **Shards:** Crystal package manager
- **SQLite3:** Development libraries
- **OpenSSL:** Development libraries
- **Node.js 22:** For Svelte build
- **pnpm:** Node package manager

---

## 11. Code Quality

### Running Ameba

Ameba is the Crystal linter. Run it to check for code issues:

```bash
# Run ameba (checks for issues)
nix develop . --command ameba

# Auto-fix correctable issues
nix develop . --command ameba --fix
```

**Recommended workflow:** Run `ameba --fix` after each major change to resolve minor issues and maintain code consistency.

### Code Organization

**File size guideline:** When a source file exceeds 800 lines, consider splitting it into multiple files. This improves:
- Readability and maintainability
- Compile times (Crystal recompiles changed files)
- Testability

**Common patterns for splitting:**
- Extract modules/classes to separate files
- Group related functionality into `services/` or `repositories/` directories
- Move utility functions to dedicated files in `src/utils/`

### Cyclomatic Complexity

Ameba will flag methods with high cyclomatic complexity (>10). Consider refactoring complex methods by:
- Extracting helper methods
- Using early returns
- Simplifying conditional logic

### Platform-Specific

**Ubuntu/Debian:**
```bash
sudo apt-get install libsqlite3-dev libssl-dev libmagic-dev
```

**macOS:**
```bash
brew install crystal openssl@3 libmagic
```

**FreeBSD:**
```bash
pkg install crystal shards sqlite3 openssl libmagic llvm19
```
