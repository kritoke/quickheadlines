## Color types for the MMCQ extraction pipeline.

import std/strutils

type
  RGB* = object
    r*, g*, b*: int

  YIQ* = object
    y*, i*, q*: float

proc toHex*(c: RGB): string =
  ## Convert RGB to hex color string (e.g. "#ff8800").
  result = "#"
  for v in [c.r, c.g, c.b]:
    result &= v.toHex(2).toLowerAscii()

proc parseHex*(hex: string): RGB =
  ## Parse "#rrggbb" to RGB.
  let h = hex.strip(chars={'#'})
  if h.len >= 6:
    RGB(r: h[0..1].parseHexInt, g: h[2..3].parseHexInt, b: h[4..5].parseHexInt)
  else: RGB()
