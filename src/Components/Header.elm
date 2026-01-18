module Components.Header exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Html.Attributes
import Theme exposing (ThemeColors, borderColor, getThemeColors, textColor)
import Time exposing (Posix, Zone)
import Types exposing (Theme(..))


view : Theme -> Maybe Posix -> Zone -> msg -> Element msg
view theme lastUpdated timeZone onToggleMsg =
    let
        colors =
            getThemeColors theme
    in
    row
        [ width fill
        , spacing 8
        , paddingXY 0 12
        , Border.widthEach { bottom = 1, top = 0, left = 0, right = 0 }
        , Border.color colors.border
        ]
        [ logoSection theme
        , rightSection theme lastUpdated timeZone onToggleMsg
        ]


logoSection : Theme -> Element msg
logoSection theme =
    row [ spacing 12 ]
        [ logoImage
        , el
            [ Font.size 24
            , Font.bold
            , Font.color (textColor theme)
            ]
            (text "QuickHeadlines")
        ]


logoImage : Element msg
logoImage =
    link []
        { url = "/"
        , label =
            el
                [ width (px 32)
                , height (px 32)
                ]
                (image [ width fill, height fill ]
                    { src = "/favicon.png"
                    , description = "QuickHeadlines Logo"
                    }
                )
        }


rightSection : Theme -> Maybe Posix -> Zone -> msg -> Element msg
rightSection theme lastUpdated timeZone onToggleMsg =
    row
        [ spacing 3
        , paddingXY 12 8
        , Background.color (rgb255 241 245 249)
        , Border.rounded 9999
        , Border.width 1
        , Border.color (rgb255 226 232 240)
        ]
        [ lastUpdatedTime theme lastUpdated timeZone
        , timelineLink theme
        , themeToggle theme onToggleMsg
        ]


lastUpdatedTime : Theme -> Maybe Posix -> Zone -> Element msg
lastUpdatedTime theme lastUpdated timeZone =
    case lastUpdated of
        Just time ->
            el
                [ Font.size 14
                , Font.medium
                , Font.color (textColor theme)
                ]
                (text (formatTime time timeZone))

        Nothing ->
            Element.none


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


timelineLink : Theme -> Element msg
timelineLink theme =
    link
        [ paddingXY 6 6
        , Border.rounded 6
        , mouseOver [ Background.color (rgb255 226 232 240) ]
        , pointer
        ]
        { url = "/timeline"
        , label =
            el
                [ width (px 20)
                , height (px 20)
                , Font.color (textColor theme)
                ]
                (text "🕐")
        }


themeToggle : Theme -> msg -> Element msg
themeToggle theme onToggleMsg =
    el
        [ paddingXY 6 6
        , Border.rounded 6
        , mouseOver [ Background.color (rgb255 226 232 240) ]
        , pointer
        , Events.onClick onToggleMsg
        ]
        (text
            (case theme of
                Light ->
                    "🌙"

                Dark ->
                    "☀️"
            )
        )
