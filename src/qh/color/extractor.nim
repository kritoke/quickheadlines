## Color extractor - port of prismatiq's ThemeExtractor orchestration.
## Decodes an image (via stb_image), builds a histogram, runs MMCQ, and
## selects background + text colors with WCAG contrast ratio.

import std/[math, options]
import stb_image/read as stbi

import ./types as colorTypes
import ./color_space
import ./mmcq

proc isIco(data: string): bool =
  data.len >= 4 and data[0] == '\x00' and data[1] == '\x00' and data[2] == '\x01' and data[3] == '\x00'

proc extractIcoPng(data: string): string =
  ## Find embedded PNG data inside an ICO file. Many ICO favicons contain
  ## PNG-encoded images. Scans for the PNG magic bytes.
  for i in 0 ..< data.len - 4:
    if data[i] == '\x89' and data[i+1] == 'P' and data[i+2] == 'N' and data[i+3] == 'G':
      return data[i .. ^1]
  data  # no PNG found, return original (stb_image will try as-is)

proc decodeImage(data: string): Option[seq[byte]] =
  ## Decode image bytes -> RGBA pixel array via stb_image.
  ## Handles ICO files by extracting embedded PNG (stb_image can't decode ICO
  ## directly - it only supports PNG/JPEG/BMP/GIF). Many favicon ICO files
  ## contain PNG-encoded images, which we extract before decoding.
  if data.len == 0: return none(seq[byte])
  # For ICO files, try to extract embedded PNG first.
  var imageData = data
  if isIco(data):
    let pngData = extractIcoPng(data)
    if pngData.len > 0 and pngData.len < data.len:
      imageData = pngData
  # Proper string -> seq[byte] (cast is unsafe under ORC).
  var bytes = newSeq[byte](imageData.len)
  for i in 0 ..< imageData.len: bytes[i] = byte(imageData[i])
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
  ## Returns (lightText, darkText). Never uses bg itself. Only considers
  ## palette colors with WCAG AA contrast (4.5:1) against bg; falls back to
  ## white/black if no palette color meets the threshold.
  let bgLum = relativeLuminance(bg)
  var bestLightContrast = 0.0
  var bestLight = RGB(r: 255, g: 255, b: 255)   # default: white (always good on dark bg)
  var bestDarkContrast = 0.0
  var bestDark = RGB(r: 0, g: 0, b: 0)           # default: black (always good on light bg)
  for c in palette:
    if c.r == bg.r and c.g == bg.g and c.b == bg.b: continue
    let lum = relativeLuminance(c)
    let ratio = contrastRatio(c, bg)
    if lum > 0.5 and ratio > bestLightContrast:
      bestLightContrast = ratio
      bestLight = c
    elif lum <= 0.5 and ratio > bestDarkContrast:
      bestDarkContrast = ratio
      bestDark = c
  # If the best palette color has < 4.5:1 contrast, fall back to pure white/black.
  if bestLightContrast < 4.5: bestLight = RGB(r: 255, g: 255, b: 255)
  if bestDarkContrast < 4.5: bestDark = RGB(r: 0, g: 0, b: 0)
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
  ## Ensures minimum WCAG AA contrast (4.5:1); falls back to white/black
  ## if the palette text color doesn't have sufficient contrast.
  let bg = parseHex(theme.bgColor)
  let lum = relativeLuminance(bg)
  let textColor = if lum < 0.5: theme.lightTextColor else: theme.darkTextColor
  let text = parseHex(textColor)
  let ratio = contrastRatio(text, bg)
  if ratio >= 4.5:
    textColor   # good contrast from palette
  elif lum < 0.5:
    "#ffffff"   # dark bg -> white text (guaranteed high contrast)
  else:
    "#000000"   # light bg -> black text (guaranteed high contrast)
