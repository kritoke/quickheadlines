## Catseye Security Scan Results (src/)

**Scan Date:** 2026-06-02
**Files Scanned:** 79 Crystal files
**Result:** 0 Errors, 20 Warnings

---

### MissingTimeout (9 findings) - Critical

HTTP::Client.new without explicit timeout - enables Slowloris DoS attacks.

- src/controllers/api_base_controller.cr lines 131, 133 (2 instances)
- src/favicon_storage.cr lines 78, 249, 269, 321, 336 (5 instances)

Fix: Add connect_timeout: 5.seconds, read_timeout: 10.seconds

---

### TOCTOU (7 findings) - High

Time-of-check to time-of-use vulnerability.

- src/config/loader.cr line 35
- src/controllers/asset_controller.cr line 17
- src/favicon_storage.cr lines 219, 233, 358
- src/utils.cr line 117

Fix: Use atomic write pattern or file locking.

---

### UnboundedRead (4 findings) - High

Potential memory exhaustion from unbounded file reads.

- src/config/loader.cr line 35
- src/controllers/api_base_controller.cr line 216
- src/controllers/asset_controller.cr line 17
- src/controllers/header_color_controller.cr line 12

Fix: Add max_size limits to File.read operations.

---

### ReDoS (1 finding) - Medium

Potential catastrophic backtracking in regex.

- src/utils/url_normalizer.cr line 106 (nested quantifiers)

Fix: Use non-backtracking regex or simplify quantifiers.

---

### SilentErrorSwallow (1 finding) - Medium

Error silently swallowed with empty handler.

- src/controllers/api_base_controller.cr line 67

Fix: Log or propagate errors.

---

### NonAtomicFileOp (2 findings) - Low

File.rename is non-atomic on some filesystems.

- src/favicon_storage.cr lines 220, 359

---

### Priority Recommendations

1. Critical: MissingTimeout - enables DoS attacks
2. High: TOCTOU, UnboundedRead - security vulnerabilities
3. Medium: SilentErrorSwallow - monitoring blind spot
4. Low: ReDoS, NonAtomicFileOp - edge cases