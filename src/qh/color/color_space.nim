## YIQ color space conversion (NTSC coefficients).
## Used by MMCQ for quantized color space indexing (5-bit per channel).

import ./types

const
  YFromR* = 0.299
  YFromG* = 0.587
  YFromB* = 0.114
  IFromR* = 0.596
  IFromG* = -0.274
  IFromB* = -0.322
  QFromR* = 0.212
  QFromG* = -0.523
  QFromB* = 0.311

const
  SigBits* = 5
  Rsh* = 8 - SigBits
  HistBins* = 1 shl SigBits        # 32
  HistSize* = HistBins * HistBins * HistBins  # 32768

proc rgbToYiq*(r, g, b: int): YIQ =
  YIQ(
    y: YFromR * r.float + YFromG * g.float + YFromB * b.float,
    i: IFromR * r.float + IFromG * g.float + IFromB * b.float,
    q: QFromR * r.float + QFromG * g.float + QFromB * b.float)

proc rgbToYiq*(c: RGB): YIQ = rgbToYiq(c.r, c.g, c.b)

proc quantize*(r, g, b: int): int =
  ## 8-bit RGB -> 15-bit histogram index.
  ((r shr Rsh) shl (2 * SigBits)) or ((g shr Rsh) shl SigBits) or (b shr Rsh)

proc quantize*(c: RGB): int = quantize(c.r, c.g, c.b)

proc dequantize*(idx: int): RGB =
  ## 15-bit histogram index -> 8-bit RGB (center of the bin).
  let r = ((idx shr (2 * SigBits)) and (HistBins - 1)) shl Rsh
  let g = ((idx shr SigBits) and (HistBins - 1)) shl Rsh
  let b = (idx and (HistBins - 1)) shl Rsh
  RGB(r: r, g: g, b: b)
