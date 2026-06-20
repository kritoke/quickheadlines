## MMCQ (Modified Median Cut Quantization) — port of prismatiq/algorithm/mmcq.cr.
## Core algorithm for extracting dominant colors from pixel data via histogram
## building + iterative median-cut splitting in 3D color space.

import std/[algorithm, sequtils]
import ./types, ./color_space

const
  MaxIterations = 1000
  Significance = 0.001

type
  VBox* = object
    ## Volume box in 3D color space (YIQ indices).
    r1*, r2*: int       # Y range [r1, r2]
    g1*, g2*: int       # I range
    b1*, b2*: int       # Q range
    count*: int         # total pixels in this box
    volume*: int        # (r2-r1+1)*(g2-g1+1)*(b2-b1+1)
    avg*: RGB           # weighted average color

proc makeVBox*(r1, r2, g1, g2, b1, b2: int; histogram: seq[uint32]): VBox =
  var count = 0
  var rs, gs, bs: int64
  for r in r1..r2:
    for g in g1..g2:
      for b in b1..b2:
        let idx = (r shl (2 * SigBits)) or (g shl SigBits) or b
        let h = histogram[idx].int
        count += h
        rs += h * ((r shl Rsh) + (1 shl (Rsh - 1)))  # center of bin
        gs += h * ((g shl Rsh) + (1 shl (Rsh - 1)))
        bs += h * ((b shl Rsh) + (1 shl (Rsh - 1)))
  let avg = if count > 0: RGB(r: rs div count, g: gs div count, b: bs div count)
            else: dequantize((r1 shl (2*SigBits)) or (g1 shl SigBits) or b1)
  VBox(r1: r1, r2: r2, g1: g1, g2: g2, b1: b1, b2: b2,
       count: count, volume: (r2-r1+1)*(g2-g1+1)*(b2-b1+1), avg: avg)

proc priority*(v: VBox): float =
  ## volume * count (used for split priority).
  v.volume.float * v.count.float

proc longestAxis*(v: VBox): int =
  ## 0=Y, 1=I, 2=Q — the axis with the largest extent.
  let dr = v.r2 - v.r1
  let dg = v.g2 - v.g1
  let db = v.b2 - v.b1
  if dr >= dg and dr >= db: 0
  elif dg >= db: 1
  else: 2

proc split*(v: VBox; histogram: seq[uint32]): (VBox, VBox) =
  ## Split the box at the median of its longest axis.
  let axis = v.longestAxis
  var total = 0
  case axis
  of 0:  # Y axis
    for r in v.r1..v.r2:
      for g in v.g1..v.g2:
        for b in v.b1..v.b2:
          total += histogram[(r shl (2*SigBits)) or (g shl SigBits) or b].int
    let half = total div 2
    var acc = 0
    var splitR = v.r1
    for r in v.r1..v.r2:
      for g in v.g1..v.g2:
        for b in v.b1..v.b2:
          acc += histogram[(r shl (2*SigBits)) or (g shl SigBits) or b].int
      if acc >= half: splitR = r; break
    result = (makeVBox(v.r1, splitR, v.g1, v.g2, v.b1, v.b2, histogram),
              makeVBox(splitR+1, v.r2, v.g1, v.g2, v.b1, v.b2, histogram))
  of 1:  # I axis
    for r in v.r1..v.r2:
      for g in v.g1..v.g2:
        for b in v.b1..v.b2:
          total += histogram[(r shl (2*SigBits)) or (g shl SigBits) or b].int
    let half = total div 2
    var acc = 0
    var splitG = v.g1
    for g in v.g1..v.g2:
      for r in v.r1..v.r2:
        for b in v.b1..v.b2:
          acc += histogram[(r shl (2*SigBits)) or (g shl SigBits) or b].int
      if acc >= half: splitG = g; break
    result = (makeVBox(v.r1, v.r2, v.g1, splitG, v.b1, v.b2, histogram),
              makeVBox(v.r1, v.r2, splitG+1, v.g2, v.b1, v.b2, histogram))
  else:  # Q axis
    for r in v.r1..v.r2:
      for g in v.g1..v.g2:
        for b in v.b1..v.b2:
          total += histogram[(r shl (2*SigBits)) or (g shl SigBits) or b].int
    let half = total div 2
    var acc = 0
    var splitB = v.b1
    for b in v.b1..v.b2:
      for r in v.r1..v.r2:
        for g in v.g1..v.g2:
          acc += histogram[(r shl (2*SigBits)) or (g shl SigBits) or b].int
      if acc >= half: splitB = b; break
    result = (makeVBox(v.r1, v.r2, v.g1, v.g2, v.b1, splitB, histogram),
              makeVBox(v.r1, v.r2, v.g1, v.g2, splitB+1, v.b2, histogram))

proc mmcq*(histogram: seq[uint32]; maxColors: int = 6): seq[RGB] =
  ## Run MMCQ on a histogram to extract `maxColors` dominant colors.
  if maxColors < 1: return @[]

  var boxes = @[makeVBox(0, HistBins-1, 0, HistBins-1, 0, HistBins-1, histogram)]
  if boxes[0].count == 0: return @[RGB()]

  var iteration = 0
  while boxes.len < maxColors and iteration < MaxIterations:
    inc iteration
    # Find the box with the highest priority to split.
    boxes.sort do (a, b: VBox) -> int: cmp(b.priority, a.priority)
    let box = boxes[0]
    if box.count == 0 or box.volume == 1: break
    let (v1, v2) = box.split(histogram)
    if v1.count == 0 and v2.count == 0: break
    boxes.delete(0)
    if v1.count > 0: boxes.add(v1)
    if v2.count > 0: boxes.add(v2)

  # Extract the average color from each box.
  boxes.sort do (a, b: VBox) -> int: cmp(b.count, a.count)
  for b in boxes:
    if b.count > 0: result.add(b.avg)
