# 🗺️ ACTIVE DESIGN PLAN: quickheadlines-ker

## 1. 🎯 Goal & Context

* **Objective**: Implement a "Story Grouping" algorithm using MinHash and LSH (Locality-Sensitive Hashing) to prevent duplicate headlines from appearing multiple times from different news sources in the timeline view.
* **System Impact**: Database schema changes, new MinHash/LSH module, modified fetcher workflow, updated timeline rendering with grouped stories UI.
* **Bead ID**: quickheadlines-ker

## 2. 🏛️ Architectural Specification (Architect Mode)

### Data Structures / Types

```crystal
# MinHash signature for story similarity detection
record StorySignature,
  id : Int64,
  item_id : Int64,
  signature : Array(UInt32),  # 100 hash values
  cluster_id : Int64?,        # Links similar stories together
  created_at : Time

# Cluster metadata
record StoryCluster,
  id : Int64,
  representative_item_id : Int64,  # The "main" story shown
  story_count : Int32,             # Number of stories in cluster
  created_at : Time

# LSH band for fast similarity lookup
record LSHBand,
  item_id : Int64,
  band_index : Int32,    # Which band (0-19 for 20 bands)
  band_hash : UInt64,    # Hash of the band's signature values
  created_at : Time

# Extended FirehoseItem with cluster info
record ClusteredFirehoseItem,
  item : Item,
  feed_title : String,
  feed_url : String,
  feed_link : String,
  favicon : String?,
  favicon_data : String?,
  header_color : String?,
  cluster_id : Int64?,
  is_representative : Bool,  # Is this the main story in the cluster?
  cluster_size : Int32?        # Total stories in this cluster
```

### Database Schema Changes

```sql
-- Add columns to existing items table
ALTER TABLE items ADD COLUMN minhash_signature BLOB;  -- Store 100 UInt32 values (400 bytes)
ALTER TABLE items ADD COLUMN cluster_id INTEGER REFERENCES items(id);

-- Create LSH bands table for fast similarity lookup
CREATE TABLE IF NOT EXISTS lsh_bands (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER NOT NULL,
  band_index INTEGER NOT NULL,
  band_hash INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
  UNIQUE(item_id, band_index)
);

CREATE INDEX IF NOT EXISTS idx_lsh_band_search ON lsh_bands(band_index, band_hash);
CREATE INDEX IF NOT EXISTS idx_items_cluster ON items(cluster_id);
```

### Logic Flow

1. **Story Ingestion Phase** (during `refresh_all`):
   - For each new item fetched from RSS feeds:
     - Compute MinHash signature from title (and optionally summary)
     - Store signature in `items.minhash_signature` column
     - Generate LSH bands from signature
     - Query `lsh_bands` table for potential matches (same band_hash in same band_index)
     - If matches found, compute exact Jaccard similarity
     - If similarity > threshold (0.7), assign same `cluster_id`
     - If no match, create new cluster with this item as representative

2. **Cluster Assignment Algorithm**:
   ```
   For each new item:
     1. Compute MinHash signature (100 hash functions)
     2. Split signature into 20 bands of 5 hashes each
     3. For each band, compute band_hash (hash of the 5 values)
     4. Query lsh_bands for items with matching band_hash in same band_index
     5. Collect all candidate items from matching bands
     6. For each candidate, compute exact Jaccard similarity
     7. If similarity > 0.7, assign same cluster_id
     8. If multiple candidates, choose highest similarity
     9. If no match, create new cluster
   ```

3. **Timeline Rendering Phase**:
   - Query items ordered by pub_date DESC
   - Group items by cluster_id
   - For each cluster:
     - Show representative item (is_representative = true)
     - Show collapsed count badge: "↳ [Favicon1] [Favicon2] (N)"
     - On expand, show all items in cluster with their favicons

### Concurrency/OTP Strategy

Per CRYSTAL_CONCURRENCY.md:

1. **Fan-Out Pattern for Signature Computation**:
   - Use `Channel(Item)` to distribute signature computation across worker fibers
   - Spawn 4-8 worker fibers (configurable via SEM)
   - Each worker computes MinHash signature and LSH bands

2. **Database Write Coordination**:
   - Use `Mutex` in `FeedCache` for all cluster-related writes
   - Batch LSH band inserts for performance (INSERT OR IGNORE multiple rows)

3. **Cluster Lookup Optimization**:
   - Cache recent cluster lookups in memory (last 1000 items)
   - Use buffered channels for cluster assignment results

## 3. 🛠️ Refactor Spec

### Code Smell Detected
- **Primitive Obsession**: Items are currently simple records without similarity metadata
- **Feature Envy**: Timeline rendering logic will need cluster information that doesn't exist

### Transformation Map
1. `src/models.cr` -> Add `StorySignature`, `StoryCluster`, `LSHBand` records
2. `src/storage.cr` -> Add cluster-related methods to `FeedCache`
3. `src/fetcher.cr` -> Integrate signature computation into `refresh_all`
4. `src/timeline.slang` -> Update to show grouped stories with expand/collapse
5. `src/timeline_page.slang` -> Add JavaScript for cluster expansion

### Refactor Pseudo-code

```text
# Phase 1: Add MinHash module
Create src/minhash.cr with:
- StoryHasher.compute_signature(text) : Array(UInt32)
- StoryHasher.similarity(sig1, sig2) : Float64
- LSH.generate_bands(signature) : Array({Int32, UInt64})

# Phase 2: Extend database schema
Add migration logic in create_schema() to add:
- items.minhash_signature column
- items.cluster_id column
- lsh_bands table with indexes

# Phase 3: Integrate into fetcher
In refresh_all():
- After fetching items, compute signatures in parallel
- Assign cluster IDs using LSH lookup
- Store signatures and bands in database

# Phase 4: Update timeline rendering
Modify timeline.slang to:
- Check if item has cluster_id
- If representative, show main story + collapsed badge
- If not representative, hide (show only on expand)
- Add expand/collapse JavaScript
```

## 4. 🚀 Implementation Steps (Developer Mode)

* [ ] **Step 1**: Create `src/minhash.cr` module with MinHash and LSH algorithms
* [ ] **Step 2**: Update `src/storage.cr` schema to add cluster columns and lsh_bands table
* [ ] **Step 3**: Add cluster-related methods to `FeedCache` class (find_similar_items, assign_cluster, get_cluster_items)
* [ ] **Step 4**: Update `src/models.cr` to add cluster-related records and extend `FirehoseItem`
* [ ] **Step 5**: Integrate signature computation into `src/fetcher.cr` refresh_all workflow
* [ ] **Step 6**: Update `src/timeline.slang` to render grouped stories with expand/collapse UI
* [ ] **Step 7**: Update `src/timeline_page.slang` JavaScript for cluster expansion
* [ ] **Step 8**: Add specs for MinHash/LSH algorithms in `spec/minhash_spec.cr`
* [ ] **Step 9**: Run quality gate (format, ameba, spec)

## 5. 🏁 The Quality Gate (Verification Checklist)

* **Linter**: `ameba --format stylish`
* **Test Command**: `crystal spec --no-color`
* **Compiler Gate**: `crystal tool format && ameba --format stylish && crystal spec --no-color`

## 6. 📝 Handoff & Discovery Notes

### Architect Notes
- **Performance Consideration**: MinHash signature computation is CPU-intensive. Use fiber pool with SEM to limit concurrent computations.
- **Memory Consideration**: Storing 100 UInt32 values per item = 400 bytes. For 10,000 items = 4MB additional storage.
- **LSH Tuning**: 20 bands of 5 hashes each gives ~87% probability of detecting >0.7 similarity. Adjust if needed.
- **Cluster Assignment Window**: Only compare against items from last 6 hours to limit database queries.
- **Edge Case**: Items without pub_date should still be clustered based on title similarity.

### Developer Notes
- The MinHash algorithm uses multiple hash functions. We'll simulate this with a single hash function and different seeds.
- LSH band hashing can use simple XOR or sum of band values.
- Cluster expansion should use morphdom for smooth DOM updates.
- Test with real RSS feeds to verify grouping works correctly.
- Monitor database query performance during cluster assignment.

### Dependencies
- No new shards required. We'll use Crystal's built-in `Digest::CRC32` or implement a simple hash function.
- Consider adding `digest` shard if needed for better hash functions.

### UI Specification
The grouped story display should look like:
```
[Favicon] Apple announces M4 chips for Mac | TechCrunch
  ↳ [Favicon] [Favicon] [Favicon] (3)
```

When expanded:
```
[Favicon] Apple announces M4 chips for Mac | TechCrunch
  ↳ [Favicon] Apple reveals M4 Mac Mini | The Verge
  ↳ [Favicon] New Mac Mini with M4 chip | Ars Technica
  ↳ [Favicon] Apple's M4 Mac Mini announced | MacRumors
```
