<img src="assets/images/logo.svg" alt="Quick Headlines Logo" width="200"/> 

# Quick Headlines 

Quick Headlines is an easily configurable and deployable recent feed dashboard. It allows you to organize your favorite RSS/Atom feeds and software releases into **tabs** for a clean, categorized view.

I wanted it to be as simple as dropping an executable and a YAML file with feeds in it. The aim is to have sane defaults, so you can get up and running quickly without fighting with it. It works great as a local dashboard or a hosted service.

## Features

- **Tabbed Interface**: Group feeds into logical categories (e.g., "Tech", "Dev", "News").
- **Software Release Tracking**: Monitor releases from GitHub, GitLab, and Codeberg in a unified view.
- **Adaptive UI**: Automatically extracts colors from site favicons to style feed headers.
- **Dark Mode**: Built-in support with a toggle, including high-contrast scrollbars and scroll-indicators for Safari compatibility.
- **Live Updates**: Automatically refreshes feeds in the background and updates the UI without a page reload using [Morphodom](https://github.com/patrick-steele-idem/morphdom).
- **Lightweight**: Single binary deployment with minimal dependencies.

## Screenshots
Mobile (Dark Mode)           |  Mobile (Light Mode)
:-------------------------:|:-------------------------:
![](ss/qh-mobile-dm-ss.png)  |  ![](ss/qh-mobile-lm-ss.png)

Desktop (Dark Mode)           |  Desktop (Light Mode)
:-------------------------:|:-------------------------:
![](ss/qh-desktop-dm-ss.png)  |  ![](ss/qh-desktop-lm-ss.png)

## Installation

Download the associated binary for your operating system from the Releases page. There are builds for Linux (arm64/amd64), FreeBSD (amd64), and macOS (arm64). You will also need to have the `feeds.yml` file in the same folder as the executable.  **Note for macOS users:** You must have OpenSSL 3 installed (`brew install openssl@3`) to run the binary.

## Building from Source

### Prerequisites

- **Crystal** (>= 1.18.2)
- **SQLite3** development libraries
- **OpenSSL** development libraries
- **Node.js/npm** (for Tailwind CSS CLI during build)

The Makefile will automatically check for these dependencies and provide installation instructions if any are missing.

### Platform-Specific Setup

#### Ubuntu / Debian

```bash
# Install Crystal compiler
curl -fsSL https://crystal-lang.org/install.sh | sudo bash

# Install system dependencies
sudo apt-get update
sudo apt-get install -y libsqlite3-dev libssl-dev pkg-config

# Clone and build
git clone https://github.com/kritoke/quickheadlines.git
cd quickheadlines
make build
```

#### Fedora / RHEL

```bash
# Install Crystal compiler
curl -fsSL https://crystal-lang.org/install.sh | sudo bash

# Install system dependencies
sudo dnf install -y sqlite-devel openssl-devel pkg-config

# Clone and build
git clone https://github.com/kritoke/quickheadlines.git
cd quickheadlines
make build
```

#### Arch Linux

```bash
# Install Crystal and dependencies
sudo pacman -S crystal sqlite openssl pkg-config

# Clone and build
git clone https://github.com/kritoke/quickheadlines.git
cd quickheadlines
make build
```

#### macOS

```bash
# Install Crystal and dependencies via Homebrew
brew install crystal openssl@3

# Clone and build
git clone https://github.com/kritoke/quickheadlines.git
cd quickheadlines
make build
```

#### FreeBSD

```bash
# Install Crystal and dependencies
pkg install crystal shards sqlite3 openssl node npm gmake

# Clone and build
git clone https://github.com/kritoke/quickheadlines.git
cd quickheadlines
gmake build
```

### Build Commands

- **Production Mode**: `make build` - Compiles optimized binary to `bin/quickheadlines`
- **Development Mode**: `make run` - Compiles and runs with live CSS reloading
- **Check Dependencies**: `make check-deps` - Verify all required dependencies are installed
- **Clean Build**: `make clean && make build` - Remove all build artifacts and rebuild

### Running the Application

```bash
# Run the compiled binary
./bin/quickheadlines

# Or use development mode
make run
```

The application will:
1. Auto-download `feeds.yml` from GitHub if missing
2. Create SQLite cache database on first run
3. Start listening on port 3030 on localhost unless you changed the port in the `feeds.yml` file.

## Usage

Edit the `feeds.yml` file to add your own content. It only requires a feed title and URL; other properties have sane defaults.

Example `feeds.yml`:

```
refresh_minutes: 10 # optional, defaults to 10
item_limit: 10 # optional, defaults to 10
server_port: 3030 # optional, defaults to 3030
page_title: "Quick Headlines" # optional, defaults to Quick Headlines
tabs:
  - name: "Tech"
    feeds:
      - title: "Hacker News"
        url: "https://news.ycombinator.com/rss"
        header_color: "orange" # optional, can take hex or color names
      - title: "Tech Radar"
        url: "https://www.techradar.com/feeds.xml"
      - title: "Ars Technica"
        url: "https://feeds.arstechnica.com/arstechnica/index"
      - title: "Hackaday"
        url: "https://hackaday.com/blog/feed/"
  - name: "Dev"
    feeds:
      - title: "Lobste.rs"
        url: "https://lobste.rs/rss"
      - title: "Google Developers"
        url: "https://developer.chrome.com/static/blog/feed.xml"
      - title: "Dev.to"
        url: "https://dev.to/feed"
    software_releases: 
      title: "Software Releases" # optional, defaults to Software Releases
      repos:
        - "crystal-lang/crystal"          # Defaults to GitHub
        - "inkscape/inkscape:gl"          # :gl for GitLab
        - "supercell/luce:cb"             # :cb for Codeberg
```

## Docker Image

You should be able to use the following docker image ```ghcr.io/kritoke/quickheadlines:latest``` to get the latest package.

## Performance & Memory Tuning

For long-running instances, especially in resource-constrained environments like Docker containers or FreeBSD jails, you can tune the Garbage Collector (Boehm GC) using environment variables to maintain a flat memory footprint:

- `GC_MARKERS=1`: Limits the number of parallel markers. Recommended for systems with low CPU core counts to reduce thread overhead.
- `GC_FREE_SPACE_DIVISOR=20`: Makes the GC more aggressive about reclaiming memory and returning it to the OS. Increasing this value (default is ~3) helps prevent slow memory growth over time.

### Setting Variables

Add them to your docker-compose.yml or docker run command (these are already made on the included docker/docker-compose files):
```yaml +environment:
GC_MARKERS=1
GC_FREE_SPACE_DIVISOR=20
```

## Contributing

1. Fork it (<https://github.com/kritoke/quickheadlines/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [kritoke](https://github.com/kritoke) - creator and maintainer

## License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
