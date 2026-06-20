## Admin token authentication - timing-safe comparison against ADMIN_SECRET env var.
## Applied to admin endpoints (POST /api/*). If ADMIN_SECRET is not set, auth
## is disabled (dev mode). Port of Crystal src/controllers/api_base_controller.cr.

import std/[strutils, times, os]

proc timingSafeEq(a, b: string): bool =
  ## Constant-time string comparison (no early exit on mismatch).
  if a.len != b.len: return false
  var diff = 0'u8
  for i in 0 ..< a.len: diff = diff or (uint8(a[i]) xor uint8(b[i]))
  diff == 0

proc checkAdminAuth*(authorization: string): bool =
  ## Validate Bearer token against ADMIN_SECRET. Returns true if authorized.
  ## If ADMIN_SECRET is empty/not set, returns true (dev mode - no auth).
  let secret = getEnv("ADMIN_SECRET", "")
  if secret.len == 0: return true
  if not authorization.startsWith("Bearer "): return false
  let token = authorization[7 .. ^1]
  timingSafeEq(token, secret)
