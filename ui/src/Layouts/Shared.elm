module Layouts.Shared exposing (layout)

import Element exposing (Attribute, Element, column, el, fill, height, htmlAttribute, padding, rgb255, row, spacing, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import ThemeTypography as Ty
import Html.Attributes
import Shared exposing (Model, Theme(..))
import Theme exposing (darkBg, surfaceColor, semantic)
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
                    "100%"

                MobileBreakpoint ->
                    "100%"

                TabletBreakpoint ->
                    "1300px"

                DesktopBreakpoint ->
                    "1600px"

        sidePadding =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    12

                MobileBreakpoint ->
                    16

                TabletBreakpoint ->
                    32

                DesktopBreakpoint ->
                    48

        borderColor =
            case theme of
                Dark ->
                    rgb255 75 75 75

                Light ->
                    rgb255 209 213 219
    in
    column
        [ width fill
        , height fill
        , Background.color bg
        , semantic "layout-container"
        ]
        [ Element.column
            [ width fill
            , Element.htmlAttribute (Html.Attributes.style "max-width" containerWidth)
            , Element.htmlAttribute (Html.Attributes.style "margin" "0 auto")
            , Element.htmlAttribute (Html.Attributes.style "padding-left" (String.fromInt sidePadding ++ "px"))
            , Element.htmlAttribute (Html.Attributes.style "padding-right" (String.fromInt sidePadding ++ "px"))
            , Border.widthEach { top = 0, right = 0, bottom = 2, left = 0 }
            , Border.color borderColor
            , Region.navigation
            , semantic "main-header"
            ]
            [ header
            , el
                [ width fill
                , height fill
                , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
                , htmlAttribute (Html.Attributes.id "main-content")
                , Region.mainContent
                , semantic "main-content-scroll"
                , case breakpoint of
                    VeryNarrowBreakpoint ->
                        Element.padding 8

                    MobileBreakpoint ->
                        Element.padding 12

                    _ ->
                        Element.padding 0
                ]
                (Element.column
                    [ width fill
                    ]
                    [ main
                    , footer
                    ]
                )
            ]
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
        , semantic "header-row"
        ]
        [ content ]


mainView : Element msg -> Element msg
mainView content =
    el
        [ width fill
        , height fill
        , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
        , htmlAttribute (Html.Attributes.id "main-content")
        , Region.mainContent
        , semantic "content-view"
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
        , Region.footer
        , semantic "main-footer"
        ]
        [ content ]
