## ADDED Requirements

### Requirement: Feed items display comment links when available
When a feed item includes a comment_url or commentary_url field from the RSS/Atom feed, the system SHALL display clickable icons that allow users to navigate to the discussion page.

#### Scenario: Feed item has comment_url
- **WHEN** a feed item contains a non-empty `comment_url` field from the fetcher
- **THEN** a subtle speech bubble icon SHALL appear inline next to the article title
- **AND** clicking the icon SHALL open the comment_url in a new browser tab

#### Scenario: Feed item has commentary_url
- **WHEN** a feed item contains a non-empty `commentary_url` field from the fetcher
- **AND** it differs from comment_url
- **THEN** a subtle chat lines icon SHALL appear inline next to the article title
- **AND** clicking the icon SHALL open the commentary_url in a new browser tab

#### Scenario: Feed item has both comment types
- **WHEN** a feed item contains both comment_url and commentary_url
- **THEN** both icons SHALL appear side by side
- **AND** each SHALL open its respective URL

#### Scenario: Feed item has no comment links
- **WHEN** a feed item does not contain comment_url or commentary_url
- **THEN** no comment icons SHALL be displayed

### Requirement: Comment icons are visually subtle
The comment icons SHALL NOT distract from the article title reading experience.

#### Scenario: Icon appearance
- **WHEN** comment icons are rendered
- **THEN** they SHALL be 16x16 pixels in size
- **AND** they SHALL use a subtle gray color that matches secondary text
- **AND** they SHALL have a tooltip showing "Comments" or "Discussion" on hover

### Requirement: Backend stores comment URLs
The system SHALL persist comment_url and commentary_url fields from feeds to enable display.

#### Scenario: New feed items with comment URLs
- **WHEN** fetching a feed that returns items with comment_url or commentary_url
- **THEN** the values SHALL be stored in the database
- **AND** they SHALL be returned in API responses

#### Scenario: API returns comment URLs
- **WHEN** client requests feed items via /api/feed_more or /api/timeline
- **THEN** the response SHALL include comment_url and commentary_url fields when present
