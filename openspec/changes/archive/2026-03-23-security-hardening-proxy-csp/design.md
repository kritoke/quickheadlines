## Context

QuickHeadlines serves a Svelte frontend from baked static assets and exposes `/proxy_image` for remote image fetches. Current proxy behavior can copy arbitrarily large responses into memory. Static responses do not consistently set browser hardening headers.

## Goals / Non-Goals

**Goals:**
- Bound memory use in `/proxy_image` by enforcing a strict maximum payload size.
- Reject proxied responses that are not images.
- Add baseline browser security headers to static responses without breaking existing frontend behavior.
- Preserve Crystal 1.18.2 compatibility.

**Non-Goals:**
- Replacing the proxy implementation with a streaming reverse proxy.
- Building per-route CSP nonce/hash policies.
- Introducing new external dependencies.

## Decisions

1. **Proxy payload cap (default constant in code):**
   - Use a fixed max byte size for proxied content (5 MB).
   - Fetch at most `max + 1` bytes and return `413` if exceeded.
   - Rationale: simple, deterministic memory ceiling and easy to reason about.

2. **Content-type allowlist for proxy responses:**
   - Accept only `image/*` response content-types.
   - Return `415` for non-image payloads.
   - Rationale: endpoint intent is image proxying; this reduces abuse surface.

3. **Baseline static security headers in one place:**
   - Add helper in `StaticController` that applies CSP and related headers to responses.
   - Apply to all static responses to keep behavior consistent.
   - Rationale: centralization avoids header drift and improves maintainability.

4. **CSP compatibility-first posture:**
   - Use a conservative policy that allows existing app behavior, then tighten later.
   - Rationale: avoid breaking production frontend while still improving defenses.

## Risks / Trade-offs

- **[Risk] Large legitimate images may be rejected** -> Mitigation: document limit and adjust constant if needed.
- **[Risk] CSP may block some future asset patterns** -> Mitigation: central helper makes policy updates straightforward.
- **[Trade-off] `unsafe-inline` in CSP for compatibility** -> Mitigation: keep policy centralized and tighten incrementally.

## Migration Plan

1. Implement proxy guardrails and static header helper.
2. Build and run specs/tests.
3. Deploy normally (no data migration needed).
4. If issues appear, rollback by reverting the change commit.

## Open Questions

- Should proxy size limit become config-driven in a follow-up change?
- Should API JSON responses also receive selected security headers in a follow-up change?
