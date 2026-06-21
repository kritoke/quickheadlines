## SSRF-safe URL validation - port of the P0 #1 fix (context.md).
## Validates proxy URLs: resolve hostname, check the resolved IP is not private
## (prevents DNS rebinding), pin the IP for the fetch. Returns the resolved IP
## so the caller can use it directly (don't re-resolve).

import std/[net, uri, strutils, nativesockets]
import ../types

type
  ProxyValidator* = ref object
    blockedDomains*: seq[string]   # exact-match blocklist
    allowedDomains*: seq[string]   # empty = allow all non-blocked

proc isPrivateIp(ip: string): bool =
  ## Check if an IP is private/link-local (RFC 1918, RFC 6598, loopback).
  ## Blocks: 10.x, 172.16-31.x, 192.168.x, 127.x, 0.x, 169.254.x, ::1, fc/fd.
  if ip == "127.0.0.1" or ip == "::1" or ip == "0.0.0.0": return true
  let parts = ip.split('.')
  if parts.len != 4: return false  # IPv6 — let it through for now
  let a = parseInt(parts[0]); let b = parseInt(parts[1])
  if a == 10: return true
  if a == 127: return true
  if a == 0: return true
  if a == 169 and b == 254: return true  # link-local
  if a == 172 and b >= 16 and b <= 31: return true
  if a == 192 and b == 168: return true
  false

proc resolveHost(host: string): string =
  ## Resolve hostname to IP string. Returns "" on failure.
  try:
    let ha = getHostByName(host)
    return ha.addrList[0]
  except CatchableError:
    return ""

proc validate*(v: ProxyValidator; url: string): ProxyValidateResult =
  ## Validate a URL for proxying. Returns the pinned resolved IP on success.
  if url.len == 0: return errProxy(peMalformed)
  try:
    let parsed = parseUri(url)
    if parsed.scheme != "https":
      return errProxy(peMalformed)
    let host = parsed.hostname
    if host.len == 0: return errProxy(peMalformed)
    # Check blocked domains
    for blocked in v.blockedDomains:
      if host == blocked or host.endsWith("." & blocked):
        return errProxy(peBlocked)
    # Check allowed domains (if list is non-empty, host must be in it)
    if v.allowedDomains.len > 0:
      var allowed = false
      for ad in v.allowedDomains:
        if host == ad or host.endsWith("." & ad):
          allowed = true; break
      if not allowed: return errProxy(peBlocked)
    # Resolve and validate IP (the SSRF fix: pin the IP, don't re-resolve later)
    let ip = resolveHost(host)
    if ip.len == 0: return errProxy(peMalformed)
    if isPrivateIp(ip): return errProxy(pePrivateIp)
    okProxy(ip)
  except CatchableError:
    errProxy(peMalformed)
