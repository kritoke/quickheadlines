require "json"
require "xml"
require "../driver"

module Fetcher
  class SoftwareDriver < Driver
    def pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?) : Result
      provider = detect_provider(url)
      return build_error_result("Unknown software provider") unless provider

      begin
        case provider
        when "github"
          pull_github(url, headers)
        when "gitlab"
          pull_gitlab(url, headers)
        when "codeberg"
          pull_codeberg(url, headers)
        else
          build_error_result("Unsupported provider")
        end
      rescue ex
        build_error_result("#{ex.class}: #{ex.message}")
      end
    end

    private def detect_provider(url : String) : String?
      return "github" if url.includes?("github.com") && url.includes?("/releases")
      return "gitlab" if url.includes?("gitlab.com") && url.includes?("/-/releases")
      return "codeberg" if url.includes?("codeberg.org") && url.includes?("/releases")
      nil
    end

    private def pull_github(url : String, headers : HTTP::Headers) : Result
      repo = extract_github_repo(url)
      return build_error_result("Invalid GitHub repo URL") unless repo

      api_url = "https://api.github.com/repos/#{repo}/releases"

      response = HTTP::Client.get(api_url, HTTP::Headers{
        "Accept" => "application/vnd.github.v3+json",
      })

      return build_error_result("GitHub API error: #{response.status_code}") unless response.status_code == 200

      releases = Array(JSON::Any).from_json(response.body)
      stable_releases = releases.reject do |release|
        release["prerelease"]?.try(&.as_bool) || release["draft"]?.try(&.as_bool)
      end

      entries = [] of Entry
      stable_releases.first(10).each do |release|
        tag = release["tag_name"]?.try(&.as_s) || ""
        name = release["name"]?.try(&.as_s).presence || tag
        html_url = release["html_url"]?.try(&.as_s) || ""
        published = release["published_at"]?.try(&.as_s)

        pub_date = published ? Time.parse_iso8601(published) : nil

        entries << Entry.new(
          "#{repo} #{name}",
          html_url,
          "",
          nil,
          pub_date,
          "github",
          tag
        )
      end

      Result.new(
        entries: entries,
        etag: response.headers["ETag"]?,
        last_modified: nil,
        site_link: "https://github.com/#{repo}",
        favicon: "https://github.com/favicon.ico",
        error_message: nil
      )
    end

    private def extract_github_repo(url : String) : String?
      match = url.match(%r{github\.com/([^/]+/[^/]+)/?})
      match ? match[1] : nil
    end

    private def pull_gitlab(url : String, headers : HTTP::Headers) : Result
      repo = extract_gitlab_repo(url)
      return build_error_result("Invalid GitLab repo URL") unless repo

      atom_url = "https://gitlab.com/#{repo}/-/releases.atom"

      response = HTTP::Client.get(atom_url)
      return build_error_result("GitLab fetch error: #{response.status_code}") unless response.status_code == 200

      entries = parse_atom_entries(response.body, "gitlab")

      site_link = "https://gitlab.com/#{repo}"

      Result.new(
        entries: entries,
        etag: response.headers["ETag"]?,
        last_modified: response.headers["Last-Modified"]?,
        site_link: site_link,
        favicon: "https://gitlab.com/favicon.ico",
        error_message: nil
      )
    end

    private def extract_gitlab_repo(url : String) : String?
      match = url.match(%r{gitlab\.com/([^/]+/[^/]+)})
      match ? match[1] : nil
    end

    private def pull_codeberg(url : String, headers : HTTP::Headers) : Result
      repo = extract_codeberg_repo(url)
      return build_error_result("Invalid Codeberg repo URL") unless repo

      atom_url = "https://codeberg.org/#{repo}/releases.atom"

      response = HTTP::Client.get(atom_url)
      return build_error_result("Codeberg fetch error: #{response.status_code}") unless response.status_code == 200

      entries = parse_atom_entries(response.body, "codeberg")

      site_link = "https://codeberg.org/#{repo}"

      Result.new(
        entries: entries,
        etag: response.headers["ETag"]?,
        last_modified: response.headers["Last-Modified"]?,
        site_link: site_link,
        favicon: "https://codeberg.org/favicon.ico",
        error_message: nil
      )
    end

    private def extract_codeberg_repo(url : String) : String?
      match = url.match(%r{codeberg\.org/([^/]+/[^/]+)})
      match ? match[1] : nil
    end

    private def parse_atom_entries(body : String, source : String) : Array(Entry)
      xml = XML.parse(body, options: XML::ParserOptions::RECOVER | XML::ParserOptions::NOENT)
      entries = [] of Entry

      xml.xpath_nodes("//entry").each do |entry|
        title_node = entry.xpath_node("title")
        title = title_node.nil? ? "Untitled" : (title_node.text.try(&.strip) || "Untitled")

        link_node = entry.xpath_node("link")
        if link_node
          link = link_node["href"]? || (link_node.text.try(&.strip) || "")
        else
          link = ""
        end

        published_node = entry.xpath_node("published") || entry.xpath_node("updated")
        pub_date = published_node ? parse_time(published_node.text) : nil

        entries << Entry.new(title, link, "", nil, pub_date, source, nil)
      end

      entries
    end

    private def parse_time(time_str : String?) : Time?
      return nil unless time_str

      formats = [
        "%a, %d %b %Y %H:%M:%S %z",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S",
      ]

      formats.each do |fmt|
        begin
          return Time.parse(time_str.strip, fmt, Time::Location::UTC)
        rescue
        end
      end

      begin
        return Time.parse_iso8601(time_str.strip)
      rescue
      end

      nil
    end
  end
end
