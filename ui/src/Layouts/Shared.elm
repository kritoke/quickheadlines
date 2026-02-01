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

        breakpoint =
            Responsive.breakpointFromWidth windowWidth

        containerWidth =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    640

                MobileBreakpoint ->
                    768

                TabletBreakpoint ->
                    1024

                DesktopBreakpoint ->
                    1280

        sidePadding =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    16

                MobileBreakpoint ->
                    16

                TabletBreakpoint ->
                    32

                DesktopBreakpoint ->
                    48
    in
    column
        [ width fill
        , height fill
        , Background.color bg
        ]
        [ header
        , el
            [ width fill
            , height fill
            , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
            , htmlAttribute (Html.Attributes.id "main-content")
            ]
            (Element.column
                [ width fill
                , Element.htmlAttribute (Html.Attributes.style "max-width" (String.fromInt containerWidth ++ "px"))
                , Element.htmlAttribute (Html.Attributes.style "margin" "0 auto")
                , Element.htmlAttribute (Html.Attributes.style "padding-left" (String.fromInt sidePadding ++ "px"))
                , Element.htmlAttribute (Html.Attributes.style "padding-right" (String.fromInt sidePadding ++ "px"))
                ]
                [ main
                , footer
                ]
            )
        ]


headerView : Theme -> Int -> Element msg -> Element msg
headerView theme windowWidth content =
    let
        bg =
            surfaceColor theme
    in
    row
        [ width fill
        , Background.color bg
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
