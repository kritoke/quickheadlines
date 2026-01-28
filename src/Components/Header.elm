module Components.Header exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Theme exposing (textColor)
import Time exposing (Posix, Zone)
import Types exposing (Theme(..))


view : Int -> Theme -> Maybe Posix -> Zone -> msg -> Element msg
view windowWidth theme lastUpdated timeZone onToggleMsg =
    let
        isMobile =
            windowWidth < 768

        logoSize =
            if isMobile then 18 else 24

        logoImgSize =
            if isMobile then 24 else 32

        metaSize =
            if isMobile then 11 else 14
    in
    row
        [ width fill
        , spacing 8
        , paddingXY 0 (if isMobile then 8 else 12)
        , Border.widthEach { top = 0, right = 0, bottom = 1, left = 0 }
        , Border.color (textColor theme)
        ]
        [ logoSection isMobile theme logoSize logoImgSize
        , rightSection isMobile theme lastUpdated timeZone metaSize onToggleMsg
        ]


logoSection : Bool -> Theme -> Int -> Int -> Element msg
logoSection isMobile theme logoSize logoImgSize =
    row
        [ spacing (if isMobile then 8 else 12)
        ]
        [ logoImage logoImgSize
        , el
            [ Font.size logoSize
            , Font.bold
            , Font.color (textColor theme)
            ]
            (text "QuickHeadlines")
        ]


logoImage : Int -> Element msg
logoImage size =
    link []
        { url = "/"
        , label =
            image
                [ width (px size)
                , height (px size)
                ]
                { src = "/favicon.png", description = "QuickHeadlines Logo" }
        }


rightSection : Bool -> Theme -> Maybe Posix -> Zone -> Int -> msg -> Element msg
rightSection isMobile theme lastUpdated timeZone metaSize onToggleMsg =
    let
        bgCol =
            if isMobile then
                rgb255 241 245 249

            else
                rgb255 241 245 249

        borderCol =
            rgb255 226 232 240

        paddingVal =
            if isMobile then 4 else 8
    in
    row
        [ spacing (if isMobile then 2 else 4)
        , padding paddingVal
        , Background.color bgCol
        , Border.rounded 9999
        , Border.width 1
        , Border.color borderCol
        ]
        [ lastUpdatedTime isMobile theme lastUpdated timeZone metaSize
        , timelineLink isMobile theme
        , themeToggle isMobile theme onToggleMsg
        ]


lastUpdatedTime : Bool -> Theme -> Maybe Posix -> Zone -> Int -> Element msg
lastUpdatedTime isMobile theme lastUpdated timeZone fontSize =
    case lastUpdated of
        Just time ->
            el
                [ Font.size fontSize
                , Font.medium
                , Font.color (textColor theme)
                ]
                (text (formatTime time timeZone))

        Nothing ->
            none


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
    month ++ " " ++ day ++ ", " ++ year


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


timelineLink : Bool -> Theme -> Element msg
timelineLink isMobile theme =
    let
        iconSize =
            if isMobile then 16 else 20
    in
    link
        [ padding 6
        , Border.rounded 6
        , pointer
        ]
        { url = "/timeline"
        , label =
            el
                [ width (px iconSize)
                , height (px iconSize)
                , Font.size iconSize
                , Font.color (textColor theme)
                , centerX
                , centerY
                ]
                (text "🕐")
        }


themeToggle : Bool -> Theme -> msg -> Element msg
themeToggle isMobile theme onToggleMsg =
    let
        iconSize =
            if isMobile then 14 else 16
    in
    Input.button
        [ padding 6
        , Border.rounded 6
        , pointer
        ]
        { onPress = Just onToggleMsg
        , label =
            el [ Font.size iconSize ]
                (text
                    (case theme of
                        Light ->
                            "🌙"

                        Dark ->
                            "☀️"
                    )
                )
        }
