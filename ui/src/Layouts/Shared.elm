module Layouts.Shared exposing (layout)

import Element exposing (Attribute, Element, column, el, fill, height, htmlAttribute, padding, rgb255, row, spacing, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import ThemeTypography as Ty
import Html.Attributes
import Shared exposing (Model, Theme(..))
import Theme exposing (darkBg, surfaceColor)
import Responsive exposing (Breakpoint(..), breakpointFromWidth, uniformPadding)


layout :
    { theme : Theme
    , windowWidth : Int
    , header : Element msg
    , footer : Element msg
    , main : Element msg
    }
    -> Element msg
layout { theme, windowWidth, header, footer, main } =
    let
        bg =
            surfaceColor theme
    in
    column
        [ width fill
        , height fill
        , Background.color bg
        ]
        [ headerView theme windowWidth header
        , mainView main
        , footerView footer
        ]


headerView : Theme -> Int -> Element msg -> Element msg
headerView theme windowWidth content =
    let
        bg =
            surfaceColor theme

        border =
            case theme of
                Dark ->
                    rgb255 55 55 55

                Light ->
                    rgb255 229 231 235

        breakpoint =
            Responsive.breakpointFromWidth windowWidth
    in
    row
        [ width fill
        , padding (Responsive.uniformPadding breakpoint)
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
        , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
        , htmlAttribute (Html.Attributes.id "main-content")
        ]
        content


footerView : Element msg -> Element msg
footerView content =
    row
        [ width fill
        , padding 16
        , spacing 8
        , Ty.small
        , Font.color (rgb255 150 150 150)
        ]
        [ content ]
