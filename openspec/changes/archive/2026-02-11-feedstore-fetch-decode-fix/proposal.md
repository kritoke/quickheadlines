# Proposal: Fix Mint FeedStore Fetch/Decode Pattern

## Why

The Mint frontend cannot make HTTP requests because the compiler does not recognize `sequence`, `await`, `Promise.then(fun (...) { ... })`, or `Promise(Never, Void)`. This blocks all API integration with the Crystal backend. We need to discover and document the actual working async patterns for this specific Mint environment.

## What Changes

- Create a working `FeedStore` with state management for feeds
- Create an `Api` module with HTTP fetching capabilities
- Document verified working patterns in `MINT_0_28_1_GUIDE.md`
- Update AGENTS.md with correct Mint guardrails
- Ensure `mint build` passes with a working bundle

## Capabilities

### New Capabilities
- `mint-async-patterns`: Verified working async/Http patterns for this Mint environment
- `mint-feed-store`: State management for feed data using Mint stores

### Modified Capabilities
- None (this is enabling new functionality)

## Impact

- Frontend: New `FeedStore` and `Api` modules in `frontend/source/`
- Documentation: New `MINT_0_28_1_GUIDE.md` in `.kilocode/skills/mint/`
- Configuration: Updated `AGENTS.md` with Mint guardrails
- Build: `mint build` produces working 58.8KB bundle
