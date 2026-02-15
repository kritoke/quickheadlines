# QuickHeadlines FreeBSD Deployment Guide

This guide covers deploying QuickHeadlines on FreeBSD using Bastille.

## Installation

### Quick Start

```bash
# Clone the bastille templates
git clone https://github.com/kritoke/bastille-templates.git /usr/local/share/bastille/templates/quickheadlines

# Create and bootstrap the jail
bastille create quickheadlines 15.0-RELEASE 10.0.0.10
bastille bootstrap 15.0-RELEASE
bastille config quickheadlines mount -f /path/to/quickheadlines /usr/local/share/quickheadlines

# Deploy
bastille template quickheadlines kritoke/quickheadlines
```

### Manual Deployment

```bash
# Clone this repository inside the jail
git clone https://github.com/kritoke/quickheadlines.git /tmp/qh

# Deploy using the Bastillefile
cd /tmp/qh/misc
bastille cmd 15.0 quickheadlines sh -c 'cd /tmp/qh/misc && bash Bastillefile'
```

### Configuration Options

QuickHeadlines can be configured via Bastille template arguments. Use `--arg` when applying the template:

```bash
# Production (latest release tag) - default
bastille template JAILNAME path/to/template

# Development (main branch)
bastille template JAILNAME path/to/template --arg MODE=dev

# For specific tag
bastille template JAILNAME path/to/template --arg TAG=v0.4.0

# Custom repository
bastille template JAILNAME path/to/template --arg REPO_URL=https://github.com/myuser/quickheadlines.git

# Skip build (use existing binary)
bastille template JAILNAME path/to/template --arg SKIP_BUILD=true

# Clear cache (recommended when switching between major versions or bleeding edge to release)
bastille template JAILNAME path/to/template --arg CLEAR_CACHE=true
```

### Service Configuration Variables

These are set in `/etc/rc.conf` for the running service:

```bash
sysrc quickheadlines_env="VAR1=value1 VAR2=value2 ..."
```

| Service Variable | Description | Default |
|------------------|-------------|---------|
| `quickheadlines_enable` | Enable service on boot | `NO` |
| `quickheadlines_svcuser` | User to run as | `qh` |
| `quickheadlines_env` | Environment variables | `GC_MARKERS=1 GC_FREE_SPACE_DIVISOR=20` |
| `quickheadlines_dir` | Install directory | `/usr/local/share/quickheadlines` |
| `quickheadlines_cachedir` | Cache directory | `/var/cache/quickheadlines` |

## Usage Examples

### Specific Release Tag

```bash
# Using --arg TAG
bastille template quickheadlines path/to/template --arg TAG=v0.4.0
```

### Development Mode (Main Branch)

```bash
# Using --arg MODE=dev
bastille template quickheadlines path/to/template --arg MODE=dev
```

### Skip Build (Use Existing Binary)

```bash
# Using --arg SKIP_BUILD=true
bastille template quickheadlines path/to/template --arg SKIP_BUILD=true
```

### Custom Repository

```bash
# Using --arg REPO_URL
bastille template quickheadlines path/to/template --arg REPO_URL=https://github.com/myuser/quickheadlines.git
```

### Combining Options

```bash
# Development mode with custom repo
bastille template quickheadlines path/to/template --arg MODE=dev --arg REPO_URL=https://github.com/myuser/quickheadlines.git
```

### Clearing Cache

When switching between major versions (e.g., v0.x to v1.x) or from bleeding edge (dev) to stable releases, clear the cache to avoid database incompatibilities:

```bash
# Clear cache before starting
bastille template quickheadlines path/to/template --arg CLEAR_CACHE=true
```

This will remove cached feed data and shards dependencies.

## Persistence

The deployment includes persistence for:

- **Shards cache**: Mounted at `/home/qh/.cache` to avoid re-downloading dependencies
- **Compiled binary**: Stored in `/usr/local/share/quickheadlines/` (persistent directory)

Cache mount point:
```
/usr/local/bastille/cache/crystal/quickheadlines -> /home/qh/.cache
```

## File Locations

| Path | Description |
|------|-------------|
| `/usr/local/share/quickheadlines/quickheadlines` | Binary |
| `/usr/local/share/quickheadlines/feeds.yml` | Configuration |
| `/var/cache/quickheadlines/` | Cache directory |
| `/var/log/quickheadlines/quickheadlines.log` | Log file |
| `/usr/local/etc/rc.d/quickheadlines` | Service script |

## Service Commands

```bash
# Start
service quickheadlines start

# Stop
service quickheadlines stop

# Restart
service quickheadlines restart

# Status
service quickheadlines status

# Reload config
service quickheadlines reload
```

## Troubleshooting

### Crystal Not Found

If you see "crystal: not found", ensure Crystal is installed:

```bash
pkg install -y crystal shards
```

### Build Fails

1. Check Crystal version: `crystal --version`
2. Clear shards cache: `rm -rf /home/qh/.cache/shards`
3. Try with SKIP_BUILD=1 to use existing binary

### Service Won't Start

```bash
# Check logs
cat /var/log/quickheadlines/quickheadlines.log

# Check binary exists
ls -la /usr/local/share/quickheadlines/quickheadlines

# Check permissions
chown qh:qh /usr/local/share/quickheadlines/quickheadlines
```

## Bastillefile Reference

The `misc/Bastillefile` performs these steps:

1. **Install dependencies**: crystal, shards, git, openssl, gmake, sqlite3, sudo, libevent
2. **Create user**: `qh` user with home at `/usr/local/share/quickheadlines`
3. **Setup cache**: Mount persistent cache at `/home/qh/.cache`
4. **Clone repo**: Clone specified tag/branch (default: latest release)
5. **Get binary**:
   - **DEV mode**: Build from source (requires Svelte + Crystal)
   - **PROD/TAG mode**: Download pre-built binary from GitHub releases
6. **Install**: Copy binary and config to `/usr/local/share/quickheadlines`
7. **Setup service**: Install rc.d script and enable service

## Notes

- **Production releases**: Use pre-built binaries from GitHub releases (no build required)
- **Development mode**: Uses `--arg MODE=dev` to build from source (requires Crystal + Node.js/pnpm)
- Crystal version: 1.18.2 (from FreeBSD ports) - Athena framework compatible
- For development mode, use `--arg MODE=dev` when applying the template to build from source
