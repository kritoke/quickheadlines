## Context

QuickHeadlines fetches RSS/Atom feeds and displays them in a timeline. The underlying fetcher.cr library version 0.8.0 now provides `comment_url`, `commentary_url`, and `is_discussion_url` fields from feeds that support comment threads or discussion pages. Currently, these fields are not captured or displayed.

## Goals / Non-Goals

**Goals:**
- Store comment_url and commentary_url from feed items in the database
- Display subtle inline SVG icons next to articles when these fields are present
- Icons open the respective URLs in a new tab

**Non-Goals:**
- Comment counting or real-time comment sync
- Social features (posting comments from QuickHeadlines)
- Caching comment thread content locally

## Decisions

### 1. Database Schema Addition
**Decision:** Add nullable TEXT columns for comment_url and commentary_url, plus INTEGER for is_discussion_url.

**Rationale:** These fields are optional per-item metadata. Using TEXT accommodates URLs of varying length. The is_discussion_url flag helps distinguish between dedicated comment systems and general discussion links.

### 2. Inline SVG Icons Over Library
**Decision:** Use inline SVG strings in Svelte components rather than adding a dependency like lucide-svelte.

**Rationale:** Only need 2 simple icons (speech bubble, chat lines). Adding a library adds unnecessary bundle weight. Inline SVGs are already used elsewhere in the codebase.

### 3. Icon Placement
**Decision:** Place icons inline to the right of the article title, before the timestamp.

**Rationale:** Keeps related actions (reading article, reading comments) grouped together. Positioned next to title as requested.

### 4. Separate Icons for Both URL Types
**Decision:** Show two separate icons when both comment_url and commentary_url are present.

**Rationale:** User preference for separate icons. Allows quick access to both discussion types without a menu click.

## Risks / Trade-offs

- **[Risk]** Some feeds may include comment URLs that are paywalled or require authentication → **Mitigation:** Links open in new tab (target="_blank"), user can evaluate
- **[Risk]** Very long comment URLs could affect layout → **Mitigation:** URLs are stored but not displayed, only icon buttons shown
- **[Risk]** Icons may not be visible on very narrow mobile screens → **Mitigation:** Desktop-first, mobile can use touch targets

## Migration Plan

1. Deploy database migration (schema.cr changes)
2. Deploy updated Crystal backend (models, repository, API)
3. Deploy Svelte frontend with icon components
4. No rollback needed - fields are optional, icons only appear when data exists
