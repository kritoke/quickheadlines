module Components.Timeline exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Time exposing (Posix, Zone)
import Types exposing (Theme(..), TimelineItem, TimelineModel)


view : Int -> Theme -> Zone -> Posix -> TimelineModel -> Element msg
view windowWidth theme zone now model =
    if model.loading && List.isEmpty model.items then
        el [ centerX, padding 50, Font.size 16 ] (text "Loading...")

    else
        column
            [ width fill
            , spacing 16
            ]
            (List.map (timelineItem theme zone now) model.items)


timelineItem : Theme -> Zone -> Posix -> TimelineItem -> Element msg
timelineItem theme zone now item =
    column
        [ width fill
        , spacing 8
        , padding 16
        , Background.color (rgb255 255 255 255)
        , Border.rounded 8
        , Border.width 1
        , Border.color (rgb255 229 231 235)
        ]
        [ row
            [ spacing 12
            , Font.size 14
            , Font.color (rgb255 107 114 128)
            , width fill
            ]
            [ el [] (text item.feedTitle)
            , el [] (text "•")
            , el [ alignRight ] (text (relativeTime zone now item.pubDate))
            ]
        , el
            [ Font.size 18
            , Font.medium
            , Font.color (rgb255 30 41 59)
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            ]
            (text item.title)
        ]



-- Relative time helper function


relativeTime : Zone -> Posix -> Maybe Posix -> String
relativeTime zone now maybePubDate =
    case maybePubDate of
        Nothing ->
            "Unknown time"

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
                "Just now"

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
