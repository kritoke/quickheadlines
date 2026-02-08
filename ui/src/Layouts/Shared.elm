module Layouts.Shared exposing (layout)

import Element exposing (Element, column, el, fill, htmlAttribute, rgb255, width)
import Element.Background as Background
import Element.Border as Border
import Element.Region as Region
import Html.Attributes
import Responsive exposing (Breakpoint(..))
import Shared exposing (Theme(..))
import Theme exposing (semantic, surfaceColor)


layout :
    { theme : Theme
    , windowWidth : Int
    , header : Element msg
    , footer : Element msg
    , main : Element msg
    , isTimeline : Bool
    }
    -> Element msg
layout { theme, windowWidth, header, footer, main, isTimeline } =
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
        , Element.height Element.fill
        , Background.color bg
        , semantic "layout-container"
        , Element.htmlAttribute (Html.Attributes.style "min-height" "0")
        ]
        [ Element.column
            [ width fill
            , Element.height Element.fill
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
            , if isTimeline then
                Element.column
                    [ width fill
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
                    [ main ]

              else
                el
                    [ width fill
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
                    main
            , el [ semantic "main-footer" ] footer
            ]
        ]
