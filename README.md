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

## Usage

Edit the `feeds.yml` file to add your own content. It only requires a feed title and URL; other properties have sane defaults.

If you are compiling from source:

- **Production Mode**: Run `make build` to compile, then run `./bin/quickheadlines`.
- **Development Mode**: Run `make run` to automatically compile and execute.

Example ```feeds.yml```:

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
