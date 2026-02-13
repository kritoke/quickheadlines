
module ThemeTypography exposing (..)

import Element exposing (Attribute)
import Element.Font as Font
import Responsive exposing (Breakpoint(..))


{-|
  Centralized typography helpers.
  Replace scattered `Font.size N` with these named helpers so desktop scaling is consistent.
  -}


title : Attribute msg
title =
    Font.size 24


subtitle : Attribute msg
subtitle =
    Font.size 20


body : Attribute msg
body =
    Font.size 16


small : Attribute msg
small =
    Font.size 12


meta : Attribute msg
meta =
    Font.size 11


button : Attribute msg
button =
    Font.size 15


size18 : Attribute msg
size18 =
    Font.size 18


size14 : Attribute msg
size14 =
    Font.size 14


size13 : Attribute msg
size13 =
    Font.size 13


hero : Breakpoint -> List (Attribute msg)
hero breakpoint =
    let
        size =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    20

                MobileBreakpoint ->
                    20

                TabletBreakpoint ->
                    28

                DesktopBreakpoint ->
                    36
    in
    [ Font.size size
    , Font.semiBold
    , Font.letterSpacing 0.6
    ]


dayHeader : Breakpoint -> List (Attribute msg)
dayHeader breakpoint =
    let
        size =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    14

                MobileBreakpoint ->
                    14

                TabletBreakpoint ->
                    16

                DesktopBreakpoint ->
                    18
    in
    [ Font.size size
    , Font.semiBold
    ]
