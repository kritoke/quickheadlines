# Proposal: fetcher-enhancements

## Summary
Enhance the fetcher.cr shard with production-ready features: retry logic with exponential backoff, configurable item limits, GitHub API rate limiting, connection pooling, and improved logging.

## Motivation
- Make the shard suitable for production use in QuickHeadlines
- Handle transient network failures gracefully
- Respect API rate limits to avoid 429 errors
- Improve observability with configurable logging

## Scope
- Add retry logic with exponential backoff to all drivers
- Add configurable item limits to RSSDriver
- Add GitHub API rate limit detection and handling
- Add HTTP connection pooling via client reuse
- Add optional logging support

## Constraints
- Keep zero-persistence principle
- Maintain backward compatibility with existing API
- Use only stdlib (no new dependencies)
