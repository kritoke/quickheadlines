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
            8

        MobileBreakpoint ->
            16

        TabletBreakpoint ->
            24

        DesktopBreakpoint ->
            -- Reduced horizontal padding for desktop to avoid excessive side spacing
            16


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
            -- Reduce excessive top padding on desktop to avoid large empty header area
            6


uniformPadding : Breakpoint -> Int
uniformPadding breakpoint =
    case breakpoint of
        VeryNarrowBreakpoint ->
            8

        MobileBreakpoint ->
            16

        TabletBreakpoint ->
            32

        DesktopBreakpoint ->
            -- Keep overall page padding reasonable on desktop
            12


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
            Element.maximum 1200 Element.fill


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
