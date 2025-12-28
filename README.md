<img src="assets/images/logo.svg" alt="Quick Headlines Logo" width="200"/> 

# Quick Headlines 


Quick Headlines is an easily configurable and deployable recent feed dashboard.  I wanted it to be as simple as dropping an executable and a YAML file with feeds in it.  The aim is to have sane defaults, so you can get up and running quickly without fighting with it.  Making it so simple that it can just run locally as well.  It does utilize some javascript libraries like [Color Thief](https://github.com/lokesh/color-thief) (for guessing a good background/text header colors) and [Morphodom](https://github.com/patrick-steele-idem/morphdom) (for hydrating the DOM with new content). It utilizes Tailwind CSS for stylings. 

## Screenshots

Mobile (Dark Mode)           |  Mobile (Light Mode)
:-------------------------:|:-------------------------:
![](ss/qh-mobile-dm-ss.png)  |  ![](ss/qh-mobile-lm-ss.png)

Desktop (Dark Mode)           |  Desktop (Light Mode)
:-------------------------:|:-------------------------:
![](ss/qh-desktop-dm-ss.png)  |  ![](ss/qh-desktop-lm-ss.png)

## Installation

Download the associated binary for your operating system from the Releases page. There are builds for Linux (arm64/amd64), FreeBSD (amd64), and macOS (arm64). You will also need to have the `feeds.yml` file in the same folder as the executable.  **Note for macOS users:** You must have OpenSSL 3 installed (`brew install openssl@3`) to run the binary.

If you are just wanting to run & compile it locally, you can run ```make build``` and then run bin\quickheadlines.  If you want to run it in development mode, run ```make run``` and it will auto execute. 

The included example feeds.yml has example tech related feeds to get you started and the default properties.  It should only require feed title and feed url, everything else should have some basic defaults to allow it to "just work."  

## Usage

Download the binary for your system and run it with the feeds.yml file in the same directory, edit the feeds.yml file as needed.  It has only been tested on Linux and Mac OS X so far.  A FreeBSD binary has been provided but not tested yet.

Example ```feeds.yml``` (only the feeds with title/url is required, it will use defaults otherwise):

```
refresh_minutes: 10
item_limit: 10
server_port: 3030
page_title: "Quick Headlines"
tabs:
  - name: "Tech"
    feeds:
      - title: "Hacker News"
        url: "https://news.ycombinator.com/rss"
        header_color: "orange"
    software_releases:
      title: "Frameworks"
      repos:
        - "crystal-lang/crystal"
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
