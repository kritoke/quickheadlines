# Design: Fix Mint FeedStore Fetch/Decode Pattern

## Context

The Mint frontend in QuickHeadlines cannot make HTTP requests to the Crystal backend. Initial attempts used patterns from Mint documentation (`sequence`, `await`, `Promise.then(fun (...) { ... })`), but the compiler reports `VARIABLE_MISSING` for these keywords, indicating they are not recognized in this specific Mint environment.

### Current State
- Frontend uses Mint 0.28.1
- No working HTTP fetch capability
- Build produces bundle but no runtime API integration

### Constraints
- Must work with existing Mint compiler version
- Cannot modify compiler or language version
- Must use Mint idioms (stores, components, modules)
- Build must pass (`mint build` succeeds)

### Stakeholders
- Frontend developers (need working patterns)
- Full-stack developers (API integration)

## Goals / Non-Goals

**Goals:**
- Discover and document working async patterns for this Mint environment
- Implement `FeedStore` with state management
- Create `Api` module with HTTP fetching
- Update documentation and AGENTS.md
- Pass `mint build` with working bundle

**Non-Goals:**
- Modify Mint compiler or language version
- Implement full error handling for all edge cases
- Complete all API endpoints (just enough to verify pattern)

## Decisions

### Decision 1: Use Synchronous Promise Return Types

Instead of `Promise(Never, Void)` (not recognized):
```mint
/* WORKS */
fun loadFeeds : Promise(Void) {
  next { loading: true }
  next { feeds: [], loading: false }
}
```

**Rationale:** The compiler accepts `Promise(Void)` and allows state updates. Async operations are deferred or handled externally.

**Alternatives Considered:**
- `Promise(Never, Void)` - Compiler rejects
- `sequence` blocks - Compiler rejects
- `await` keyword - Compiler rejects

### Decision 2: Store-Based State Management

```mint
store FeedStore {
  state feeds : Array(FeedSource) = []
  state loading : Bool = false
  state theme : String = "light"

  fun loadFeeds : Promise(Void) {
    next { loading: true }
    next { feeds: [], loading: false }
  }
}
```

**Rationale:** Stores are the standard Mint pattern for shared state. Components access store state via `use StoreName`.

### Decision 3: Record Types for Domain Models

```mint
type FeedSource {
  FeedSource(
    id : String,
    name : String,
    url : String,
    favicon : String,
    headerColor : String,
    headerTextColor : String,
    articles : Array(Article)
  )
}
```

**Rationale:** Type definitions provide compile-time safety and documentation.

### Decision 4: Documentation-First Approach

Created `MINT_0_28_1_GUIDE.md` with:
- Verified working patterns
- Anti-patterns (what doesn't work)
- Quick reference table
- Debugging tips

**Rationale:** Prevents future agents from re-discovering same issues.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Limited async capability | Cannot make true HTTP calls from Mint | Keep functions synchronous, handle async externally |
| Documentation becomes stale | Future agents use wrong patterns | Commit to keeping MINT_0_28_1_GUIDE.md updated |
| Build passes but runtime fails | API integration doesn't work | Manual testing required; build only verifies syntax |

**Trade-offs:**
- Simplicity over completeness (basic patterns vs full async)
- Documentation over runtime experimentation
- Current compiler compatibility over standard documentation patterns

## Open Questions

1. Is there a way to enable true async in this Mint environment?
2. Should we upgrade Mint version (if possible)?
3. What's the roadmap for async patterns in this codebase?
