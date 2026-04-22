## 1. Implementation

- [x] 1.1 Add `extract_base_domain(url)` helper method to ClusteringEngine
- [x] 1.2 Add `same_base_domain?(url1, url2)` helper method to ClusteringEngine
- [x] 1.3 Add `feed_url` field to ClusteringItem record
- [x] 1.4 Update `find_similar_pairs_lsh` to skip same-domain pairs
- [x] 1.5 Update clustering query to fetch feed_url

## 2. Testing & Verification

- [x] 2.1 Run crystal build to verify no syntax errors
- [x] 2.2 Run crystal spec to verify all tests pass
- [x] 2.3 Run ameba to verify code quality (pre-existing complexity warning in clustering_service.cr)

## 3. Cleanup

- [x] 3.1 Archive OpenSpec change
