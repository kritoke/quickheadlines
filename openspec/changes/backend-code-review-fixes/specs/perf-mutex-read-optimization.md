# perf-mutex-read-optimization

**Owner:** Backend Team  
**Status:** proposed

## Overview

Remove mutex synchronization from read-only methods in `ClusteringRepository`. SQLite in WAL mode supports concurrent readers. Serializing all reads with a mutex is unnecessary and creates contention under load.

## Requirements

### REQ-001: Write-Only Mutex
The following methods are write operations and retain `@mutex.synchronize`:
- `store_item_signature`
- `store_lsh_bands`
- `assign_cluster`
- `assign_clusters_bulk`
- `clear_clustering_metadata`

### REQ-002: Lock-Free Reads
The following methods are read-only and remove `@mutex.synchronize`:
- `get_item_signature`
- `get_item_title`
- `get_item_feed_id`
- `get_feed_id`
- `get_cluster_size`
- `cluster_representative?`
- `get_item_id`
- `get_item_ids_batch`
- `get_cluster_info_batch`
- `get_cluster_items`
- `find_lsh_candidates`
- `all_clusters`
- `get_cluster_items_full`
- `find_all_items_excluding`
- `find_by_keywords`

### REQ-003: WAL Mode Confirmed
`PRAGMA journal_mode = WAL` is set in `DatabaseService` initialization, confirming concurrent reads are safe.

## Acceptance Criteria

- [ ] All read methods execute without acquiring `@mutex`
- [ ] All write methods still synchronize via `@mutex`
- [ ] `PRAGMA journal_mode = WAL` is verified at startup
- [ ] Concurrent read operations from multiple fibers are safe (no race conditions in tests)

## Affected Files

- `src/storage/clustering_repo.cr` — Remove mutex from read methods
