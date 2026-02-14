# Svelte 5 Migration

## Summary
Migrated frontend from Elm to Svelte 5 with Runes for improved developer experience and modern reactivity patterns.

## Motivation
- Svelte 5 provides better TypeScript support
- Runes (`$state`, `$derived`, `$effect`) provide clearer reactivity
- Better tooling and IDE support
- Simpler build process with Vite
- Larger community and ecosystem

## Implementation
- Created new Svelte 5 project in `frontend/` directory
- Implemented theme store with proper Svelte 5 reactivity
- Created FeedBox, TimelineView, TabBar components
- Used Tailwind CSS 4 for styling with class-based dark mode
- Embedded frontend assets via BakedFileSystem in Crystal binary
- Updated CI/CD workflows for Node.js/pnpm builds
- Updated Dockerfile with multi-stage build
- Updated Bastillefile for FreeBSD deployment

## Files Changed
- `frontend/` - New Svelte 5 application
- `src/web/assets.cr` - BakedFileSystem for frontend
- `src/web/static_controller.cr` - Serves Svelte SPA routes
- `.github/workflows/` - Updated for Svelte builds
- `Dockerfile` - Multi-stage build with Node.js + Crystal
- `misc/Bastillefile` - FreeBSD deployment updates
- `README.md` - Updated documentation
- `AGENTS.md` - Updated with Svelte 5 patterns
- `justfile` - Replaced makefile with just commands
- Deleted Elm/Mint related files
