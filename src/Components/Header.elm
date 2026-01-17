module Components.Header exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Theme exposing (.., ThemeColors, getThemeColors, textColor, borderColor)
import Time exposing (Posix, Zone)


view : Theme -> Maybe Posix -> Zone -> Element msg
view theme lastUpdated timeZone =
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
        [ logoSection
        , rightSection theme lastUpdated timeZone
        ]


logoSection : Element msg
logoSection =
    row [ spacing 12 ]
        [ logoImage
        , el
            [ Font.size 24
            , Font.bold
            , Font.color (textColor Light)
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


rightSection : Theme -> Maybe Posix -> Zone -> Element msg
rightSection theme lastUpdated timeZone =
    row
        [ spacing 3
        , paddingXY 12 8
        , Background.color (rgb255 241 245 249)
        , Border.rounded 9999
        , Border.width 1
        , Border.color (rgb255 226 232 240)
        ]
        [ lastUpdatedTime lastUpdated timeZone
        , timelineLink
        , themeToggle theme
        ]


lastUpdatedTime : Maybe Posix -> Zone -> Element msg
lastUpdatedTime lastUpdated timeZone =
    case lastUpdated of
        Just time ->
            el
                [ Font.size 14
                , Font.medium
                , Font.color (textColor Light)
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
            if hour >= 12 then "PM" else "AM"

        displayHour =
            if hour > 12 then hour - 12 else if hour == 0 then 12 else hour
    in
    month ++ " " ++ day ++ ", " ++ year ++ " at " ++ String.fromInt displayHour ++ ":" ++ minute ++ " " ++ ampm


monthToString : Time.Month -> String
monthToString month =
    case month of
        Time.Jan -> "January"
        Time.Feb -> "February"
        Time.Mar -> "March"
        Time.Apr -> "April"
        Time.May -> "May"
        Time.Jun -> "June"
        Time.Jul -> "July"
        Time.Aug -> "August"
        Time.Sep -> "September"
        Time.Oct -> "October"
        Time.Nov -> "November"
        Time.Dec -> "December"


timelineLink : Element msg
timelineLink =
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
                , Font.color (textColor Light)
                ]
                (html "🕐")
        }


themeToggle : Theme -> Element msg
themeToggle theme =
    el
        [ paddingXY 6 6
        , Border.rounded 6
        , mouseOver [ Background.color (rgb255 226 232 240) ]
        , pointer
        ]
        (text
            (case theme of
                Light ->
                    "🌙"

                Dark ->
                    "☀️"
            )
        )
