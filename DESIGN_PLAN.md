# 🗺️ ACTIVE DESIGN PLAN: Gray Icons Fix - Favicon Fallback Enhancement

## 1. 🎯 Goal & Context

* **Objective**: Fix gray icons on dev tab and other feeds when favicons aren't returned, with Google favicon fetch fallback
* **System Impact**: Templates, favicon storage, and server routes need updates for robust favicon fallback
* **Bead ID**: Gray Icons Fix

## 2. 🏛️ Architectural Specification

### Current State Analysis

1. **Templates** (`feed_boxes.slang`, `timeline.slang`):
   - Have local path check: `data.starts_with?("/favicons/")`
   - Have Google fallback in `else` clause
   - **Problem**: Templates use local path without verifying file exists on disk

2. **Favicon Storage** (`favicon_storage.cr`):
   - Saves favicons to `public/favicons/` with hash-based filenames
   - `get_or_fetch()` returns cached local path or `nil`
   - **Problem**: Templates may reference cached paths for files that don't exist yet

3. **Server** (`server.cr`):
   - `handle_favicon()` serves files from `public/favicons/`
   - Returns 404 with "Favicon not found" message
   - **Problem**: No on-demand fetch mechanism for missing favicons

### Root Cause

Templates use `favicon_data` cached values without verifying the file exists on disk. If a favicon was referenced but the fetch failed, the template still uses the cached local path, resulting in 404 errors.

### Solution: Dual-Layer Fallback

1. **Template Layer**: Verify local file exists before using local path
2. **Server Layer**: On-demand fetch for missing favicons with async storage

## 3. 🚀 Implementation Steps

### Step 1: Add Favicon Verification Module

**File**: `src/favicon_storage.cr`

Add method to verify favicon file exists:

```crystal
module FaviconStorage
  # Check if a cached favicon file exists on disk
  def self.exists?(url : String) : Bool
    hash = OpenSSL::Digest.new("SHA256").new
    hash.update(url)
    hash_hex = hash.final.hexstring
    
    @@mutex.synchronize do
      possible_extensions.each do |ext|
        filename = "#{hash_hex[0...16]}.#{ext}"
        filepath = File.join(FAVICON_DIR, filename)
        return true if File.exists?(filepath)
      end
    end
    false
  end
end
```

### Step 2: Modify Templates for File Verification

**File**: `src/feed_boxes.slang`

Change favicon logic to verify file exists:

```slang
- elsif (data = feed.favicon_data) && !data.empty? && data.starts_with?("/favicons/")
  - if File.exists?("public#{data}")  # Verify file exists
    img src="#{data}" ...
  - else
    - host = feed.site_link.empty? ? feed.url : feed.site_link
    - if parsed = URI.parse(host)
      - if parsed_host = parsed.host
        img src="https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64" ...
```

**File**: `src/timeline.slang`

Apply same pattern to timeline view.

### Step 3: Add On-Demand Favicon Fetch Endpoint

**File**: `src/server.cr`

Add route and handler:

```crystal
# Route: GET /api/favicons/fetch?url=<encoded_url>
get "/api/favicons/fetch" do |context|
  url = context.params["url"]?
  return {error: "Missing url parameter"}.to_json if url.nil?
  
  if cached = FaviconStorage.get_or_fetch(url)
    {success: true, favicon: cached}.to_json
  else
    # Trigger async fetch
    spawn { fetch_favicon_uri(url) rescue nil }
    {success: false, message: "Fetching favicon..."}.to_json
  end
end
```

### Step 4: Update Template to Use On-Demand Fetch

**File**: `src/feed_boxes.slang`

Add JavaScript to fetch missing favicons:

```slang
javascript:
  function fetchMissingFavicon(element, url) {
    fetch(`/api/favicons/fetch?url=${encodeURIComponent(url)}`)
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          element.src = data.favicon;
        }
      });
  }
```

### Step 5: Ensure Favicon Initialization on Startup

**File**: `src/quickheadlines.cr`

Ensure `FaviconStorage.init` is called before server starts:

```crystal
FaviconStorage.init
start_server(port)
```

## 4. 🏁 Quality Gate

* **Linter**: `ameba --format stylish` (0 failures)
* **Format**: `crystal tool format` (no diffs)
* **Compiler**: `crystal build src/quickheadlines.cr` (no warnings)
* **Test**: `crystal spec` (all passing)

## 5. 📝 Handoff Notes

### Edge Cases to Handle

1. **SVG favicons**: May need different `img` tag attributes
2. **Large favicons**: >100KB should use Google fallback
3. **Network timeouts**: Async fetch should have timeout protection
4. **Concurrent fetches**: Multiple requests for same favicon should share results

### Security Considerations

* Validate URL parameters to prevent SSRF attacks
* Limit favicon fetch rate per IP
* Sanitize file paths in `handle_favicon`

### Performance Impact

* Template file checks (`File.exists?`) are fast (stat call)
* On-demand fetch is async, won't block page render
* Favicon cache remains in memory for fast lookup

## 6. Files to Modify

1. `src/favicon_storage.cr` - Add `exists?` method
2. `src/feed_boxes.slang` - Add file verification and fallback
3. `src/timeline.slang` - Add file verification and fallback
4. `src/server.cr` - Add on-demand favicon fetch endpoint
5. `src/quickheadlines.cr` - Ensure favicon initialization
