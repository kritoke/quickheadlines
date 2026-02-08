## 1. Reproduction & Logging

- [ ] 1.1 Add/verify `scripts/check_favicons.cr` prints detailed trace for a list of hosts
- [ ] 1.2 Run the script against InfoWorld, Network World, TechCrunch, A List Apart and collect traces

## 2. Quick Fix Experiment

- [ ] 2.1 Increase `FaviconStorage::MAX_SIZE` from 100KB to 200KB for ICO content
- [ ] 2.2 Rebuild and run the server; verify whether favicons re-appear for failing hosts

## 3. Validation & Tests

- [ ] 3.1 Add unit test for `ico_magic?` using a sample ICO fixture
- [ ] 3.2 Add test for saving behavior when image size exceeds threshold

## 4. Follow-up Work (only if experiment fails)

- [ ] 4.1 Implement ICO→PNG conversion pipeline (separate change) or use a safer storage approach
- [ ] 4.2 Add integration-only specs and document owner/rollback plan
