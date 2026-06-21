## Color extractor - port of prismatiq's ThemeExtractor orchestration.
## Decodes an image (via stb_image), builds a histogram, runs MMCQ, and
## selects background + text colors with WCAG contrast ratio.

import std/[strutils, math, options]
import stb_image/read as stbi
import ../types
import ./types as colorTypes
import ./color_space
import ./mmcq

proc decodeImage(data: string): Option[seq[byte]] =
  ## Decode image bytes -> RGBA pixel array via stb_image.
  if data.len == 0: return none(seq[byte])
  # Proper string -> seq[byte] (cast is unsafe under ORC: string and seq
  # have different memory layouts).
  var bytes = newSeq[byte](data.len)
  for i in 0 ..< data.len: bytes[i] = byte(data[i])
  var w, h, ch: int
  try:
    let pixels = stbi.loadFromMemory(bytes, w, h, ch, 4)  # 4 = RGBA
    if pixels.len == 0: return none(seq[byte])
    some(pixels)
  except stbi.STBIException:
    none(seq[byte])

proc buildHistogram(pixels: seq[byte]): seq[uint32] =
  ## Build a 32768-bin histogram from RGBA pixel data.
  result = newSeq[uint32](HistSize)
  for i in countup(0, pixels.len - 4, 4):
    let r = pixels[i].int
    let g = pixels[i+1].int
    let b = pixels[i+2].int
    let a = pixels[i+3]
    if a < 128: continue  # skip transparent pixels
    result[quantize(r, g, b)] += 1

proc relativeLuminance*(c: RGB): float =
  ## WCAG 2.0 relative luminance (0.0 = black, 1.0 = white).
  proc linearize(v: int): float =
    let s = v.float / 255.0
    if s <= 0.03928: s / 12.92
    else: pow((s + 0.055) / 1.055, 2.4)
  0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b)

proc contrastRatio*(a, b: RGB): float =
  ## WCAG contrast ratio between two colors (1:1 to 21:1).
  let la = relativeLuminance(a)
  let lb = relativeLuminance(b)
  let lighter = max(la, lb)
  let darker = min(la, lb)
  (lighter + 0.05) / (darker + 0.05)

proc selectTextColors*(bg: RGB; palette: seq[RGB]): (RGB, RGB) =
  ## Select light and dark text colors with best contrast against bg.
  ## Returns (lightText, darkText).
  var bestLightContrast = 0.0
  var bestLight = RGB(r: 255, g: 255, b: 255)
  var bestDarkContrast = 0.0
  var bestDark = RGB(r: 0, g: 0, b: 0)
  for c in palette:
    let lum = relativeLuminance(c)
    let contrast = contrastRatio(c, bg)
    if lum > 0.5 and contrast > bestLightContrast:
      bestLightContrast = contrast
      bestLight = c
    elif lum <= 0.5 and contrast > bestDarkContrast:
      bestDarkContrast = contrast
      bestDark = c
  (bestLight, bestDark)

type ThemeResult* = object
  bgColor*: string           # hex
  lightTextColor*: string    # hex
  darkTextColor*: string     # hex

proc extractTheme*(imageData: string; maxColors = 6): Option[ThemeResult] =
  ## Full pipeline: decode image -> histogram -> MMCQ -> select colors.
  let pixels = decodeImage(imageData)
  if pixels.isNone: return none(ThemeResult)
  let histogram = buildHistogram(pixels.get)
  let palette = mmcq(histogram, maxColors)
  if palette.len == 0: return none(ThemeResult)
  let bg = palette[0]  # most dominant color
  let (lightText, darkText) = selectTextColors(bg, palette)
  some(ThemeResult(
    bgColor: bg.toHex,
    lightTextColor: lightText.toHex,
    darkTextColor: darkText.toHex))

proc selectTextColor*(theme: ThemeResult): string =
  ## Pick light or dark text for a background: dark bg -> light text,
  ## light bg -> dark text. Returns a hex color string.
  let bg = parseHex(theme.bgColor)
  let lum = relativeLuminance(bg)
  if lum < 0.5: theme.lightTextColor else: theme.darkTextColor
