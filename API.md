# QuickHeadlines API Documentation

## Overview

QuickHeadlines provides a REST API for fetching feeds, timeline items, and clusters. The server runs on port 8080 by default.

## Base URL

```
http://localhost:8080
```

## Endpoints

### Feeds

#### GET /api/feeds

Fetch all feeds with optional tab filtering.

**Query Parameters:**
- `tab` (optional): Filter by tab name. Use `all` for all feeds.

**Response:**
```json
{
  "tabs": [
    { "name": "Tech" },
    { "name": "Security" }
  ],
  "active_tab": "all",
  "feeds": [
    {
      "tab": "",
      "url": "https://example.com/feed.xml",
      "title": "Example Feed",
      "display_link": "example.com",
      "site_link": "https://example.com",
      "favicon": "/favicons/abc123.ico",
      "header_color": null,
      "header_text_color": null,
      "items": [...],
      "total_item_count": 20
    }
  ]
}
```

### Timeline

#### GET /api/timeline

Fetch timeline items from the last N days with cluster information.

**Query Parameters:**
- `limit` (optional): Number of items to return. Default: 35
- `offset` (optional): Pagination offset. Default: 0
- `days` (optional): Number of days to look back. Default: 7

**Response:**
```json
{
  "items": [
    {
      "id": "12345",
      "title": "Article Title",
      "link": "https://example.com/article",
      "pub_date": 1769718000000,
      "feed_title": "Example Feed",
      "feed_url": "https://example.com/feed.xml",
      "feed_link": "https://example.com",
      "favicon": "/favicons/abc123.ico",
      "header_color": null,
      "header_text_color": null,
      "cluster_id": "12345",
      "is_representative": true,
      "cluster_size": 1
    }
  ],
  "has_more": true,
  "total_count": 378
}
```

**Fields:**
- `cluster_id`: ID of the cluster this item belongs to (null if unclustered)
- `is_representative`: Whether this is the first/primary item in the cluster
- `cluster_size`: Number of items in the cluster (1 = unclustered)

### Clusters

#### GET /api/clusters

Fetch all clustered stories.

**Response:**
```json
{
  "clusters": [
    {
      "id": "12345",
      "representative": {
        "id": "12345",
        "title": "Primary Article",
        "link": "https://example.com/article1",
        "pub_date": 1769718000000,
        "feed_title": "Feed 1",
        "feed_url": "https://feed1.com",
        "feed_link": "https://feed1.com",
        "favicon": "/favicons/abc.ico",
        "favicon_data": "/favicons/abc.ico",
        "header_color": null
      },
      "others": [
        {
          "id": "12346",
          "title": "Similar Article",
          "link": "https://example.com/article2",
          "pub_date": 1769717500000,
          "feed_title": "Feed 2",
          "feed_url": "https://feed2.com",
          "feed_link": "https://feed2.com",
          "favicon": "/favicons/def.ico",
          "favicon_data": "/favicons/def.ico",
          "header_color": null
        }
      ],
      "cluster_size": 2
    }
  ],
  "total_count": 15
}
```

#### GET /api/clusters/{id}/items

Fetch all items in a specific cluster.

**Response:**
```json
{
  "cluster_id": "12345",
  "items": [
    {
      "id": "12345",
      "title": "Article Title",
      "link": "https://example.com/article",
      "pub_date": 1769718000000,
      "feed_title": "Example Feed",
      "feed_url": "https://example.com/feed.xml",
      "feed_link": "https://example.com",
      "favicon": "/favicons/abc.ico",
      "favicon_data": "/favicons/abc.ico",
      "header_color": null
    }
  ]
}
```

### Clustering

#### POST /api/run-clustering

Manually trigger clustering on uncategorized items. Runs in the background.

**Response:**
```
Clustering started in background
```

**Status Code:** 202 (Accepted)

**Notes:**
- Processes up to 500 uncategorized items per run
- Uses Hybrid Clustering (LSH + Jaccard similarity verification)
- Runs asynchronously, check timeline for results

### Status

#### GET /api/status

Get the current system status including clustering state.

**Response:**
```json
{
  "is_clustering": true,
  "active_jobs": 5
}
```

**Fields:**
- `is_clustering`: Whether clustering jobs are currently running
- `active_jobs`: Number of active clustering jobs

### Clustering Algorithm (v0.5.0+)

QuickHeadlines uses a **Hybrid Clustering** approach for grouping similar stories:

1. **LSH Candidate Discovery**: Fast candidate lookup using Locality-Sensitive Hashing
2. **Jaccard Verification**: Direct Jaccard similarity check on normalized headlines
3. **Stop-word Filtering**: Removes common words (the, and, says, etc.) before comparison
4. **Length-Aware Thresholds**:
   - Short headlines (< 5 words): 0.85 threshold
   - Standard headlines: 0.70 threshold
   - Minimum 4 non-stop words required for clustering

This replaces the previous LSH-only approach for higher precision grouping.

### Version

#### GET /api/version

Get version information for update checking.

**Response:**
```json
{
  "updated_at": 1769718000000
}
```

#### GET /version

Get version as plain text (UNIX timestamp).

### Static Files

#### GET /_app/*

Svelte 5 application assets (immutable, cacheable).

#### GET /favicon.png
#### GET /favicon.svg
#### GET /favicon.ico

Site favicons.

#### GET /favicons/{hash}.{ext}

Cached favicons by hash.

### Proxy

#### GET /proxy_image

Proxy images to avoid CORS issues.

**Query Parameters:**
- `url`: URL of the image to proxy

## Response Format

All JSON responses use camelCase field names. Dates are UNIX timestamps in milliseconds.

## Error Handling

Errors return appropriate HTTP status codes:
- `400`: Bad Request (missing parameters)
- `404`: Not Found
- `500`: Internal Server Error

## Rate Limiting

No rate limiting is currently implemented, but the server may throttle feed fetching internally.

## Background Jobs

The server runs periodic background jobs:
- **Feed Refresh**: Fetches new items from all feeds (every ~15 minutes)
- **Clustering**: Runs automatically on newly fetched items
- **Cache Cleanup**: Removes items older than 14 days (configurable via `cache_retention_hours`)

Use `/api/run-clustering` to manually cluster existing items.
