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
- Every new dependency is a liability
- Prefer standard library or core framework features first

---

## 8. Common Tasks

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
1. Edit Svelte files in `frontend/src/`
2. Run `just nix-build` to rebuild
3. Restart server to see changes

### Debug Feed Fetching
```yaml
# Add to feeds.yml
debug: true
```

---

## 9. Troubleshooting

### Crystal Build Fails
```bash
# Ensure dependencies are installed
nix develop . --command shards install

# Clean and rebuild
just clean && just nix-build
```

### Frontend Not Updating
```bash
# BakedFileSystem requires rebuild
just nix-build

# Clear browser cache or hard refresh (Ctrl+Shift+R)
```

### Cache Issues
```bash
# Clear cache directory
rm -rf ~/.cache/quickheadlines/

# Or set custom cache location
export QUICKHEADLINES_CACHE_DIR=/tmp/quickheadlines
```

---

## 10. Dependencies

### Required (Auto-installed via Nix)
- **Crystal:** >= 1.18.2
- **Shards:** Crystal package manager
- **SQLite3:** Development libraries
- **OpenSSL:** Development libraries
- **Node.js 22:** For Svelte build
- **pnpm:** Node package manager

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
