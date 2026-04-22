# Implementation Tasks

## Task 1: Backend - Cursor-based Pagination
- [x] 1.1 Add cursor-based pagination to `/api/timeline` endpoint
- [x] 1.2 Return `has_more` and `cursor` in timeline response

## Task 2: Frontend - Timeline Store Updates
- [x] 2.1 Add pagination state to timeline store
- [x] 2.2 Add loadMore function for infinite scroll

## Task 3: Backend - API Tests
- [ ] 3.1 Create spec/api/ directory
- [ ] 3.2 Add API controller specs

## Task 4: Frontend - Type Generation
- [ ] 4.1 Create types generated from backend DTOs

## Task 5: Pre-commit Hooks
- [ ] 5.1 Add git hooks for lint and test

---

## Notes

- Branch already created: `api-improvements`
- Remote: `origin/api-improvements`
- Backend cursor-based pagination implemented
- Frontend updated to use cursor pagination
- All Crystal tests pass (173 examples, 0 failures)
