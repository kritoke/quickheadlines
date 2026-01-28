module Components.FeedBody exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Theme exposing (borderColor, cardColor, textColor)
import Time exposing (Posix)
import Types exposing (FeedItem, Theme(..))


view : Int -> Posix -> Theme -> List FeedItem -> Element msg
view windowWidth now theme items =
    let
        isMobile =
            windowWidth < 768

        textCol =
            textColor theme

        borderCol =
            borderColor theme

        mutedCol =
            rgb255 148 163 184

        bodyBg =
            cardColor theme
    in
    if List.isEmpty items then
        el
            [ centerX
            , centerY
            , Font.color mutedCol
            , Font.size 14
            ]
            (text "No items available")

    else
        column
            [ htmlAttribute (Html.Attributes.class "feed-body")
            , Background.color bodyBg
            , padding 12
            , spacing 0
            , width fill
            , height fill
            , if isMobile then
                htmlAttribute (Html.Attributes.style "overflow-y" "visible")

              else
                htmlAttribute (Html.Attributes.style "overflow-y" "auto")
            , htmlAttribute (Html.Attributes.style "scrollbar-width" "thin")
            , htmlAttribute (Html.Attributes.style "scrollbar-color" "rgba(0,0,0,0.2) transparent")
            , htmlAttribute (Html.Attributes.style "overflow-scrolling" "touch")
            , htmlAttribute (Html.Attributes.class "feed-body-scrollable")
            ]
            (List.map (feedItemView windowWidth now theme textCol borderCol mutedCol) items)


feedItemView : Int -> Posix -> Theme -> Color -> Color -> Color -> FeedItem -> Element msg
feedItemView windowWidth now theme textCol borderCol mutedCol item =
    let
        isMobile =
            windowWidth < 768

        fontSize =
            if isMobile then 13 else 14

        timeFontSize =
            if isMobile then 11 else 12
    in
    row
        [ width fill
        , spacing 8
        , paddingXY 0 6
        , htmlAttribute (Html.Attributes.style "min-width" "0")
        ]
        [ el
            [ width (px 6)
            , height (px 6)
            , Border.width 2
            , Border.color borderCol
            , Border.rounded 3
            , alignTop
            ]
            none
        , paragraph
            [ Element.width fill
            , Font.size fontSize
            , Font.color textCol
            , htmlAttribute (Html.Attributes.style "word-break" "break-word")
            , htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "line-height" "1.4")
            , htmlAttribute (Html.Attributes.style "flex-shrink" "1")
            ]
            [ link
                [ htmlAttribute (Html.Attributes.style "color" "inherit")
                , htmlAttribute (Html.Attributes.style "text-decoration" "none")
                ]
                { url = item.link, label = text item.title }
            ]
        , el
            [ Font.size timeFontSize
            , Font.color mutedCol
            , Font.light
            , alignTop
            , htmlAttribute (Html.Attributes.style "flex-shrink" "0")
            , htmlAttribute (Html.Attributes.style "white-space" "nowrap")
            ]
            (text (relativeTime now item.pubDate))
        ]


relativeTime : Posix -> Maybe Posix -> String
relativeTime now maybePubDate =
    case maybePubDate of
        Nothing ->
            ""

        Just pubDate ->
            let
                nowMillis =
                    Time.posixToMillis now

                pubMillis =
                    Time.posixToMillis pubDate

                diffMillis =
                    nowMillis - pubMillis

                diffMinutes =
                    diffMillis // 60000

                diffHours =
                    diffMinutes // 60

                diffDays =
                    diffHours // 24
            in
            if diffMinutes < 1 then
                "now"

            else if diffMinutes < 60 then
                String.fromInt diffMinutes ++ "m"

            else if diffHours < 24 then
                String.fromInt diffHours ++ "h"

            else if diffDays < 7 then
                String.fromInt diffDays ++ "d"

            else if diffDays < 30 then
                String.fromInt (diffDays // 7) ++ "w"

            else if diffDays < 365 then
                String.fromInt (diffDays // 30) ++ "mo"

            else
                String.fromInt (diffDays // 365) ++ "y"
