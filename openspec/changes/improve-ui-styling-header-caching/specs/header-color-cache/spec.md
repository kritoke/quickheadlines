# Specification: Header Color Caching

## Overview

This specification defines the header color caching system that stores extracted colors in localStorage to prevent flashing on page refresh.

## Requirements

### Requirement: Cache Header Colors on Extraction
When header colors are extracted via ColorThief, they SHALL be stored in localStorage with the current timestamp.

#### Scenario: Store extracted colors
- **WHEN** ColorThief extracts colors from a feed header
- **THEN** the colors are saved to localStorage under the key `qh_header_colors`
- **AND** the cache entry includes a timestamp
- **AND** the cache entry includes the feed URL for identification

### Requirement: Apply Cached Colors on Page Load
On page load, cached header colors SHALL be applied immediately before ColorThief extraction.

#### Scenario: Apply cached colors immediately
- **WHEN** the page loads
- **THEN** the system checks localStorage for cached header colors
- **AND** if cache exists and is not expired, cached colors are applied immediately
- **AND** cached colors are applied via inline styles to prevent flash

### Requirement: Cache Expiration
Cached colors SHALL expire after 7 days.

#### Scenario: Expired cache triggers re-extraction
- **WHEN** cached colors are older than 7 days
- **THEN** ColorThief re-extracts colors from the favicon
- **AND** the new colors replace the expired cache

#### Scenario: Non-expired cache prevents extraction
- **WHEN** cached colors are less than 7 days old
- **THEN** ColorThief extraction is skipped
- **AND** cached colors remain in use

### Requirement: Cache Format
Cached data SHALL include:
- Feed URL or identifier
- Background color (hex/rgb)
- Text color (hex/rgb)
- Timestamp of extraction

#### Scenario: Cache structure
- **WHEN** cache is saved
- **THEN** it is stored as JSON with the format:
  ```json
  {
    "https://example.com/feed.xml": {
      "bg": "#ff6b6b",
      "text": "#ffffff",
      "timestamp": 1738684800
    }
  }
  ```

## Implementation Notes

- Use localStorage API for persistence
- Handle quota exceeded errors gracefully
- Fall back to theme colors if cache read fails
