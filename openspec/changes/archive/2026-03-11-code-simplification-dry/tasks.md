## 1. Frontend Refactoring

- [x] 1.1 Replace JSON.parse(JSON.stringify()) with deepClone in feedStore.svelte.ts
- [x] 1.2 Create generic apiFetch wrapper in api.ts to eliminate repeated fetch/error handling
- [x] 1.3 Run frontend tests to verify changes

## 2. Crystal Backend - DTO Consolidation

- [ ] 2.1 Verify StoryResponse exists in src/dtos/story_dto.cr
- [ ] 2.2 Remove duplicate StoryResponse from src/api.cr and import from dto instead
- [ ] 2.3 Verify build succeeds after DTO changes

## 3. Crystal Backend - Repository Mapping

- [x] 3.1 Extract map_row_to_story method in StoryRepository
- [ ] 3.2 Extract entity mapping helpers in FeedRepository
- [x] 3.3 Run Crystal specs to verify changes

## 4. Crystal Backend - Controller Simplification

- [x] 4.1 Consolidate validate_limit/validate_offset/validate_days into single validate_int method
- [ ] 4.2 Break up large API controller methods into focused private helpers
- [x] 4.3 Verify build succeeds

## 5. Verification

- [x] 5.1 Run `just nix-build` to verify full build
- [ ] 5.2 Run Crystal specs: `nix develop . --command crystal spec`
- [x] 5.3 Run frontend tests: `cd frontend && npm run test`
