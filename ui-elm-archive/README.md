# Elm UI Archive

This directory contains the original Elm frontend for QuickHeadlines, preserved for historical reference.

**Status:** Archived (February 2026)

The frontend has been rewritten in **Svelte 5** and is now located in the `/frontend` directory.

## Why the Migration?

- Svelte 5's runes-based reactivity (`$state`, `$derived`, `$effect`) provides cleaner state management
- Better TypeScript integration
- Smaller bundle size with SvelteKit's static adapter
- Simpler build process with Vite

## Structure

- `src/` - Original Elm source files
- `dist/` - Compiled Elm output
- `elm.json` - Elm package configuration
- `review/` - Elm review configuration

## Running the Elm Version

The Elm code is no longer maintained. To view the last working version:

```bash
cd ui-elm-archive
elm reactor
# Open http://localhost:8000
```
