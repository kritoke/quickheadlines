module Layouts.Shared exposing (layout)

import Element exposing (Attribute, Element, column, el, fill, height, padding, rgb255, row, spacing, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Shared exposing (Theme(..))
import Theme exposing (darkBg, surfaceColor)


layout :
    { theme : Theme
    , header : Element msg
    , footer : Element msg
    , main : Element msg
    }
    -> Element msg
layout { theme, header, footer, main } =
    let
        bg =
            surfaceColor theme
    in
    column
        [ width fill
        , height fill
        , Background.color bg
        ]
        [ headerView theme header
        , mainView main
        , footerView footer
        ]


headerView : Theme -> Element msg -> Element msg
headerView theme content =
    let
        bg =
            surfaceColor theme

        border =
            case theme of
                Dark ->
                    rgb255 55 55 55

                Light ->
                    rgb255 229 231 235
    in
    row
        [ width fill
        , padding 16
        , Background.color bg
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        , Border.color border
        ]
        [ content ]


mainView : Element msg -> Element msg
mainView content =
    el
        [ width fill
        , height fill
        ]
        content


footerView : Element msg -> Element msg
footerView content =
    row
        [ width fill
        , padding 16
        , spacing 8
        , Font.size 12
        , Font.color (rgb255 150 150 150)
        ]
        [ content ]
