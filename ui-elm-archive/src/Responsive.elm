module Responsive exposing 
  ( Breakpoint(..)
  , breakpointFromWidth
  , isMobile
  , isVeryNarrow
  , horizontalPadding
  , verticalPadding
  , uniformPadding
  , containerMaxWidth
  , timelineTimeColumnWidth
  , timelineClusterPadding
  )

import Element exposing (Element, Length)


type Breakpoint
    = VeryNarrowBreakpoint
    | MobileBreakpoint
    | TabletBreakpoint
    | DesktopBreakpoint


breakpointFromWidth : Int -> Breakpoint
breakpointFromWidth width =
    if width < 480 then
        VeryNarrowBreakpoint

    else if width < 768 then
        MobileBreakpoint

    else if width < 1024 then
        TabletBreakpoint

    else
        DesktopBreakpoint


isMobile : Breakpoint -> Bool
isMobile breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            True

        MobileBreakpoint ->
            True

        TabletBreakpoint ->
            False

        DesktopBreakpoint ->
            False


isVeryNarrow : Breakpoint -> Bool
isVeryNarrow breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            True

        _ ->
            False


horizontalPadding : Breakpoint -> Int
horizontalPadding breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            -- Match v0.4.0: px-4 = 16px on mobile
            16

        MobileBreakpoint ->
            -- Match v0.4.0: px-4 = 16px on mobile landscape
            16

        TabletBreakpoint ->
            -- Match v0.4.0: md:px-12 = 48px on tablet
            48

        DesktopBreakpoint ->
            -- Match v0.4.0: lg:px-24 = 96px on desktop
            96


verticalPadding : Breakpoint -> Int
verticalPadding breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            8

        MobileBreakpoint ->
            16

        TabletBreakpoint ->
            32

        DesktopBreakpoint ->
            -- Restore reasonable desktop vertical padding (was 60, reduced too much)
            24


uniformPadding : Breakpoint -> Int
uniformPadding breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            -- Match v0.4.0: px-4 = 16px on mobile
            16

        MobileBreakpoint ->
            -- Match v0.4.0: px-4 = 16px on mobile landscape
            16

        TabletBreakpoint ->
            -- Match v0.4.0: md:px-12 = 48px on tablet
            32

        DesktopBreakpoint ->
            -- Match v0.4.0: lg:px-24 = 96px on desktop - but reduce for cleaner look
            48


containerMaxWidth : Breakpoint -> Element.Length
containerMaxWidth breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            Element.fill

        MobileBreakpoint ->
            Element.fill

        TabletBreakpoint ->
            Element.maximum 1024 Element.fill

        DesktopBreakpoint ->
            Element.maximum 1600 Element.fill


timelineTimeColumnWidth : Breakpoint -> Int
timelineTimeColumnWidth breakpoint =
    if isVeryNarrow breakpoint then
        60

    else
        85


timelineClusterPadding : Breakpoint -> Int
timelineClusterPadding breakpoint =
    if isVeryNarrow breakpoint then
        70

    else
        105
