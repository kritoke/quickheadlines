# state-atomic-clustering

**Owner:** Backend Team  
**Status:** proposed

## Overview

Fix the TOCTOU (time-of-check-time-of-use) race condition in clustering job state management. Currently `StateStore.clustering?` (read) and `StateStore.clustering = true` (write) are separate operations, allowing concurrent clustering jobs to slip through the gap.

## Requirements

### REQ-001: Clustering Mutex
Add `@@clustering_mutex : Mutex` to `StateStore`.

### REQ-002: Atomic Start
New method `StateStore.start_clustering_if_idle : Bool` performs atomic check-and-set:

```crystal
def self.start_clustering_if_idle : Bool
  @@clustering_mutex.synchronize do
    return false if @@current.clustering
    @@current = @@current.copy_with(clustering: true)
    true
  end
end
```

### REQ-003: Clustering Start Time Tracking
Add `@@clustering_start_time : Time?` to `StateStore`. When clustering starts, record `Time.utc`. This enables watchdog detection of stuck jobs.

### REQ-004: Stuck Job Watchdog
`AppBootstrap.start_clustering_scheduler` checks `StateStore.clustering_start_time` periodically. If a clustering job has been running for >4 hours, it logs a warning and sets `clustering = false` to allow retry.

### REQ-005: Callers Updated
All callers of `StateStore.clustering?` before setting `clustering = true` are updated to use `start_clustering_if_idle`:
- `ClusteringService#recluster_all`
- `ClusteringService#recluster_with_lsh`
- `AppBootstrap#run_initial_clustering`

## Acceptance Criteria

- [ ] `StateStore.start_clustering_if_idle` is atomic (verified by concurrent test)
- [ ] Only one clustering job can run at a time (verified by concurrent test)
- [ ] Stuck clustering jobs (>4h) are detected and released
- [ ] `StateStore.clustering?` + `StateStore.clustering = true` pattern is eliminated

## Affected Files

- `src/models.cr` — `StateStore` module — add mutex, start_time, `start_clustering_if_idle`
- `src/services/clustering_service.cr` — Update callers
- `src/services/app_bootstrap.cr` — Add watchdog check
