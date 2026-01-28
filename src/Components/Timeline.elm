module Components.Timeline exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Theme exposing (borderColor, cardColor, textColor)
import Time exposing (Posix, Zone, toDay, toMonth, toYear)
import Types exposing (Theme(..), TimelineItem, TimelineModel)


view : Int -> Theme -> Zone -> Posix -> TimelineModel -> Element msg
view windowWidth theme zone now model =
    let
        isMobile =
            windowWidth < 768

        textCol =
            textColor theme

        cardCol =
            cardColor theme

        borderCol =
            borderColor theme

        mutedCol =
            rgb255 148 163 184

        titleSize =
            if isMobile then 15 else 18

        metaSize =
            if isMobile then 12 else 14

        groupedItems =
            groupByDay zone model.items
    in
    if model.loading && List.isEmpty model.items then
        el
            [ centerX
            , padding 50
            , Font.size 16
            , Font.color textCol
            ]
            (text "Loading...")

    else
        column
            [ width fill
            , spacing (if isMobile then 16 else 24)
            ]
            (List.map (daySection isMobile zone now textCol cardCol borderCol mutedCol titleSize metaSize) groupedItems)


type alias DayGroup =
    { date : Posix
    , items : List TimelineItem
    }


groupByDay : Zone -> List TimelineItem -> List DayGroup
groupByDay zone items =
    let
        sortedItems =
            List.sortBy
                (\item ->
                    case item.pubDate of
                        Just pubDate ->
                            Time.posixToMillis pubDate

                        Nothing ->
                            0
                )
                items
                |> List.reverse
    in
    groupByDayHelp zone [] sortedItems


groupByDayHelp : Zone -> List ( ( Int, Time.Month, Int ), List TimelineItem ) -> List TimelineItem -> List DayGroup
groupByDayHelp zone accum items =
    case items of
        [] ->
            List.map (\( key, dayItems ) -> { date = getDateFromKey zone key dayItems, items = dayItems }) accum

        item :: rest ->
            let
                key =
                    case item.pubDate of
                        Just pubDate ->
                            ( toYear zone pubDate, toMonth zone pubDate, toDay zone pubDate )

                        Nothing ->
                            ( 0, Time.Jan, 0 )
            in
            case accum of
                (k, groupItems) :: restAcc ->
                    if k == key then
                        groupByDayHelp zone ((k, item :: groupItems) :: restAcc) rest

                    else
                        groupByDayHelp zone ((key, [ item ]) :: accum) rest

                [] ->
                    groupByDayHelp zone ((key, [ item ]) :: accum) rest


getDateFromKey : Zone -> ( Int, Time.Month, Int ) -> List TimelineItem -> Posix
getDateFromKey zone key items =
    case items of
        [] ->
            Time.millisToPosix 0

        first :: _ ->
            case first.pubDate of
                Just pd ->
                    pd

                Nothing ->
                    Time.millisToPosix 0


daySection : Bool -> Zone -> Posix -> Color -> Color -> Color -> Color -> Int -> Int -> DayGroup -> Element msg
daySection isMobile zone now textCol cardCol borderCol mutedCol titleSize metaSize dayGroup =
    column
        [ width fill
        , spacing (if isMobile then 12 else 16)
        ]
        [ dayHeader isMobile zone now dayGroup.date
        , column
            [ width fill
            , spacing (if isMobile then 8 else 12)
            ]
            (List.map (timelineItem isMobile zone now textCol cardCol borderCol mutedCol titleSize metaSize) dayGroup.items)
        ]


dayHeader : Bool -> Zone -> Posix -> Posix -> Element msg
dayHeader isMobile zone now date =
    let
        nowYear =
            toYear zone now

        nowMonth =
            toMonth zone now

        nowDay =
            toDay zone now

        dateYear =
            toYear zone date

        dateMonth =
            toMonth zone date

        dateDay =
            toDay zone date

        headerText =
            if dateYear == nowYear && dateMonth == nowMonth && dateDay == nowDay then
                "Today"

            else
                let
                    yesterdayMillis =
                        Time.posixToMillis now - 86400000

                    yesterdayDate =
                        Time.millisToPosix yesterdayMillis

                    yYear =
                        toYear zone yesterdayDate

                    yMonth =
                        toMonth zone yesterdayDate

                    yDay =
                        toDay zone yesterdayDate
                in
                if dateYear == yYear && dateMonth == yMonth && dateDay == yDay then
                    "Yesterday"

                else
                    formatDate zone date

        mutedColor =
            rgb255 148 163 184
    in
    el
        [ Font.size (if isMobile then 13 else 14)
        , Font.medium
        , Font.color mutedColor
        , paddingEach { top = 8, bottom = 4, left = 0, right = 0 }
        ]
        (text headerText)


formatDate : Zone -> Posix -> String
formatDate zone date =
    let
        month =
            toMonth zone date |> monthToString

        day =
            toDay zone date |> String.fromInt

        year =
            toYear zone date |> String.fromInt
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


timelineItem : Bool -> Zone -> Posix -> Color -> Color -> Color -> Color -> Int -> Int -> TimelineItem -> Element msg
timelineItem isMobile zone now textCol cardCol borderCol mutedCol titleSize metaSize item =
    let
        faviconUrl =
            if item.favicon /= "" then
                item.favicon

            else
                "/favicon.png"
    in
    column
        [ width fill
        , spacing 8
        , padding (if isMobile then 12 else 16)
        , Background.color cardCol
        , Border.rounded 8
        , Border.width 1
        , Border.color borderCol
        ]
        [ row
            [ spacing 8
            , width fill
            , alignTop
            ]
            [ image
                [ width (px 16)
                , height (px 16)
                , Border.rounded 2
                , alignTop
                ]
                { src = faviconUrl, description = item.feedTitle ++ " favicon" }
            , el
                [ Font.size metaSize
                , Font.color mutedCol
                , width fill
                ]
                (text item.feedTitle)
            , el
                [ Font.size metaSize
                , Font.color mutedCol
                ]
                (text (relativeTime zone now item.pubDate))
            ]
        , link
            [ Font.size titleSize
            , Font.medium
            , Font.color textCol
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "line-height" "1.4")
            , width fill
            ]
            { url = item.link, label = text item.title }
        ]



-- Relative time helper function


relativeTime : Zone -> Posix -> Maybe Posix -> String
relativeTime zone now maybePubDate =
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
                ""

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
