<img src="assets/images/logo.svg" alt="Quick Headlines Logo" width="200"/> 

# Quick Headlines 


Quick Headlines is an easily configurable and deployable recent feed dashboard.  I wanted it to be as simple as dropping an executable and a YAML file with feeds in it.  The aim is to have sane defaults, so you can get up and running quickly without fighting with it.  Making it so simple that it can just run locally as well.  It does utilize some javascript libraries like [Color Thief](https://github.com/lokesh/color-thief) (for guessing a good background/text header colors) and [Morphodom](https://github.com/patrick-steele-idem/morphdom) (for hydrating the DOM with new content). It utilizes Tailwind CSS for stylings. 

## Installation

Since the application is very much in early development, there are no releases just yet (binaries are eventually planned to be available to align with the simple deployment).  Until then, the easiest way to use the program is to clone the repo and modify the feeds.yml as needed.  

If you are just wanting to run it locally, there is a shell script that should execute the required steps called ```run_QH.sh```.  It will build the program and then run it.  If you are wanting to run it in development mode, there is a different shell script that should do the commands for you called ```dev_QH.sh```.  

The included example feeds.yml has example tech related feeds to get you started and the default properties.  It should only require feed title and feed url, everything else should have some basic defaults to allow it to "just work."  

## Usage

Run ./run_QH.sh to have it automatically build and then run the program in "production" mode, edit the feeds.yml file as needed.  It has only been tested on Linux and Mac OS X so far.

Example ```feeds.yml``` (only the feeds with title/url is required, it will use defaults otherwise):

```
refresh_minutes: 10
item_limit: 10
server_port: 3030
page_title: "Quick Headlines"
feeds:
  - title: "Hacker News"
    url: "https://news.ycombinator.com/rss"
    header_color: "orange"
  - title: "Tech Radar"
    url: "https://www.techradar.com/feeds.xml"
    header_color: "pink"
  - title: "Ars Technica"
    url: "https://feeds.arstechnica.com/arstechnica/index"
    header_color: "orange"
```

## Development

TODO

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
