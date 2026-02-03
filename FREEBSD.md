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

QuickHeadlines can be configured via environment variables. Set these **before running bastille bootstrap/template**:

```bash
# For development mode (main branch)
export QUICKHEADLINES_DEV=1

# For specific tag
export QUICKHEADLINES_TAG=v0.5.0

# Custom repository
export QUICKHEADLINES_REPO_URL=https://github.com/myuser/quickheadlines.git

# Then run bootstrap/template
bastille bootstrap quickheadlines
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

### Development Mode (Main Branch)

```bash
# Set environment variable before bootstrap
export QUICKHEADLINES_DEV=1
bastille bootstrap quickheadlines

# Or set it inline
env QUICKHEADLINES_DEV=1 bastille bootstrap quickheadlines
```

### Specific Release Tag

```bash
# Set environment variable before bootstrap
export QUICKHEADLINES_TAG=v0.5.0
bastille bootstrap quickheadlines

# Or set it inline
env QUICKHEADLINES_TAG=v0.5.0 bastille bootstrap quickheadlines
```

### Skip Build (Use Existing Binary)

```bash
# Set environment variable before bootstrap
export QUICKHEADLINES_SKIP_BUILD=1
bastille bootstrap quickheadlines

# Or set it inline
env QUICKHEADLINES_SKIP_BUILD=1 bastille bootstrap quickheadlines
```

### Custom Repository

```bash
# Set environment variable before bootstrap
export QUICKHEADLINES_REPO_URL=https://github.com/myuser/quickheadlines.git
bastille bootstrap quickheadlines

# Or set it inline
env QUICKHEADLINES_REPO_URL=https://github.com/myuser/quickheadlines.git bastille bootstrap quickheadlines
```

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
5. **Install deps**: Run `shards install --production` (skips development dependencies that may cause issues)
6. **Build**: Compile binary (always builds and replaces existing binary unless SKIP_BUILD=1)
7. **Install**: Copy binary and config to `/usr/local/share/quickheadlines` (binary already installed during build)
8. **Setup service**: Install rc.d script and enable service

## Notes

- Crystal version: 1.18.2 (from FreeBSD ports) - Athena framework compatible
- Elm.js is pre-compiled and included in the repository
- No node/npm required for FreeBSD deployment
- Development dependencies (like ameba) are skipped during installation to avoid compilation issues with Crystal 1.18.2
- Binary is always rebuilt and replaced during deployment (set SKIP_BUILD=1 to preserve existing binary)
