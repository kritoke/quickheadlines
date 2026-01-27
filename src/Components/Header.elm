module Components.Header exposing (view)

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Theme exposing (textColor)
import Time exposing (Posix, Zone)
import Types exposing (Theme(..))


view : Theme -> Maybe Posix -> Zone -> msg -> Html msg
view theme lastUpdated timeZone onToggleMsg =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "width" "100%"
        , Html.Attributes.style "gap" "0.5rem"
        , Html.Attributes.style "padding-top" "0.75rem"
        , Html.Attributes.style "padding-bottom" "0.75rem"
        , Html.Attributes.style "border-bottom-width" "1px"
        , Html.Attributes.style "border-top-width" "0px"
        , Html.Attributes.style "border-left-width" "0px"
        , Html.Attributes.style "border-right-width" "0px"
        , Html.Attributes.style "border-style" "solid"
        , Html.Attributes.style "border-color" (textColor theme)
        ]
        [ logoSection theme
        , rightSection theme lastUpdated timeZone onToggleMsg
        ]


logoSection : Theme -> Html msg
logoSection theme =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "gap" "0.75rem"
        ]
        [ logoImage
        , Html.span
            [ Html.Attributes.style "font-size" "1.5rem"
            , Html.Attributes.style "font-weight" "700"
            , Html.Attributes.style "color" (textColor theme)
            ]
            [ Html.text "QuickHeadlines" ]
        ]


logoImage : Html msg
logoImage =
    Html.a
        [ Html.Attributes.href "/" ]
        [ Html.img
            [ Html.Attributes.src "/favicon.png"
            , Html.Attributes.alt "QuickHeadlines Logo"
            , Html.Attributes.style "width" "32px"
            , Html.Attributes.style "height" "32px"
            ]
            []
        ]


rightSection : Theme -> Maybe Posix -> Zone -> msg -> Html msg
rightSection theme lastUpdated timeZone onToggleMsg =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "gap" "0.25rem"
        , Html.Attributes.style "padding" "0.5rem 0.75rem"
        , Html.Attributes.style "background-color" "#f1f5f9"
        , Html.Attributes.style "border-radius" "9999px"
        , Html.Attributes.style "border-width" "1px"
        , Html.Attributes.style "border-color" "#e2e8f0"
        ]
        [ lastUpdatedTime theme lastUpdated timeZone
        , timelineLink theme
        , themeToggle theme onToggleMsg
        ]


lastUpdatedTime : Theme -> Maybe Posix -> Zone -> Html msg
lastUpdatedTime theme lastUpdated timeZone =
    case lastUpdated of
        Just time ->
            Html.span
                [ Html.Attributes.style "font-size" "0.875rem"
                , Html.Attributes.style "font-weight" "500"
                , Html.Attributes.style "color" (textColor theme)
                ]
                [ Html.text (formatTime time timeZone) ]

        Nothing ->
            Html.text ""


formatTime : Posix -> Zone -> String
formatTime time zone =
    let
        month =
            Time.toMonth zone time |> monthToString

        day =
            Time.toDay zone time |> String.fromInt

        year =
            Time.toYear zone time |> String.fromInt

        hour =
            Time.toHour zone time

        minute =
            Time.toMinute zone time |> String.fromInt |> String.padLeft 2 '0'

        ampm =
            if hour >= 12 then
                "PM"

            else
                "AM"

        displayHour =
            if hour > 12 then
                hour - 12

            else if hour == 0 then
                12

            else
                hour
    in
    month ++ " " ++ day ++ ", " ++ year ++ " at " ++ String.fromInt displayHour ++ ":" ++ minute ++ " " ++ ampm


monthToString : Time.Month -> String
monthToString month =
    case month of
        Time.Jan ->
            "January"

        Time.Feb ->
            "February"

        Time.Mar ->
            "March"

        Time.Apr ->
            "April"

        Time.May ->
            "May"

        Time.Jun ->
            "June"

        Time.Jul ->
            "July"

        Time.Aug ->
            "August"

        Time.Sep ->
            "September"

        Time.Oct ->
            "October"

        Time.Nov ->
            "November"

        Time.Dec ->
            "December"


timelineLink : Theme -> Html msg
timelineLink theme =
    Html.a
        [ Html.Attributes.href "/timeline"
        , Html.Attributes.style "padding" "0.375rem"
        , Html.Attributes.style "border-radius" "0.375rem"
        , Html.Attributes.style "cursor" "pointer"
        , Html.Attributes.style "display" "flex"
        , Html.Attributes.style "align-items" "center"
        , Html.Attributes.style "justify-content" "center"
        ]
        [ Html.span
            [ Html.Attributes.style "width" "1.25rem"
            , Html.Attributes.style "height" "1.25rem"
            , Html.Attributes.style "color" (textColor theme)
            ]
            [ Html.text "🕐" ]
        ]


themeToggle : Theme -> msg -> Html msg
themeToggle theme onToggleMsg =
    Html.div
        [ Html.Attributes.style "padding" "0.375rem"
        , Html.Attributes.style "border-radius" "0.375rem"
        , Html.Attributes.style "cursor" "pointer"
        , Html.Attributes.style "display" "flex"
        , Html.Attributes.style "align-items" "center"
        , Html.Attributes.style "justify-content" "center"
        , Html.Events.onClick onToggleMsg
        ]
        [ Html.text
            (case theme of
                Light ->
                    "🌙"

                Dark ->
                    "☀️"
            )
        ]
