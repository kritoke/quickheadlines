# Design: fetcher.cr Ingestion Engine

## 1. Unified Entry Structure
The shard will output a standardized `Fetcher::Entry` record to ensure consistent data regardless of the source.

```crystal
module Fetcher
  record Entry,
    title : String,
    url : String,
    content : String,
    author : String?,
    published_at : Time?,
    source_type : String,
    version : String?
end
```

## 2. Driver Architecture
Use an abstract Driver class to handle different protocols.
- `Fetcher::RSSDriver`: Uses XML to parse `<item>` or `<entry>` tags.
- `Fetcher::RedditDriver`: Appends .json to subreddit URLs, handles public JSON endpoints, and flattens the `data.children` nesting.
- `Fetcher::SoftwareDriver`: Handles GitHub Releases API, GitLab/Codeberg Atom feeds.

## 3. The "Smart" Fetcher
The main entry point `Fetcher.pull(url, headers)` will:
- Identify the protocol (Regex-based URL matching).
- Instantiate the correct Driver.
- Handle HTTP timeouts and User-Agent rotation.
- Return a `Fetcher::Result` containing the entries and the new ETag/Last-Modified headers.

## 4. HTTP Client Wrapper
- Use Crystal's native `HTTP::Client` (stdlib).
- Implement ETag/Last-Modified conditional request handling.
- Add retry logic with exponential backoff.
- Configurable timeouts per-request.

## 5. Integration Plan
- Main App: Update shard.yml to point to the local path `./shared/fetcher`.
- Nix: No new system dependencies needed (uses stdlib).
