module Pages.Timeline exposing (Model, Msg(..), init, update, view, subscriptions)

import Api exposing (TimelineItem, fetchTimeline)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Http
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (cardColor, errorColor, surfaceColor, textColor, mutedColor, borderColor)
import Time exposing (Posix, toDay, toMonth, toYear, Zone)


type alias Model =
    { items : List TimelineItem
    , loading : Bool
    , error : Maybe String
    , hasMore : Bool
    }


init : Shared.Model -> ( Model, Cmd Msg )
init shared =
    ( { items = []
      , loading = True
      , error = Nothing
      , hasMore = True
      }
    , fetchTimeline 50 0 GotTimeline
    )


type Msg
    = GotTimeline (Result Http.Error Api.TimelineResponse)
    | ToggleTheme


update : Shared.Model -> Msg -> Model -> ( Model, Cmd Msg )
update shared msg model =
    case msg of
        GotTimeline (Ok response) ->
            ( { model
                | items = response.items
                , loading = False
                , error = Nothing
                , hasMore = response.hasMore
              }
            , Cmd.none
            )

        GotTimeline (Err _) ->
            ( { model
                | loading = False
                , error = Just "Failed to load timeline"
              }
            , Cmd.none
            )

        ToggleTheme ->
            ( model, Cmd.none )


view : Shared.Model -> Model -> Element Msg
view shared model =
    let
        theme =
            shared.theme

        isMobile =
            shared.windowWidth < 768

        paddingValue =
            if isMobile then
                16

            else
                24

        bg =
            surfaceColor theme

        txtColor =
            textColor theme

        mutedTxt =
            mutedColor theme
    in
    column
        [ width fill
        , height fill
        , spacing 20
        , padding paddingValue
        , Background.color bg
        ]
        [ el
            [ Font.size (if isMobile then 20 else 24)
            , Font.bold
            , Font.color txtColor
            ]
            (text "Timeline")
        , if model.loading && List.isEmpty model.items then
            el
                [ centerX
                , centerY
                , Font.size 16
                , Font.color mutedTxt
                ]
                (text "Loading...")

          else if model.error /= Nothing then
            el
                [ centerX
                , centerY
                , Font.size 16
                , Font.color errorColor
                ]
                (text "Error loading timeline")

          else
            column
                [ width fill
                , spacing 16
                ]
                (groupByDay shared.zone shared.now theme model.items)
        ]


type alias DayGroup =
    { date : Posix
    , items : List TimelineItem
    }


groupByDay : Zone -> Posix -> Theme -> List TimelineItem -> List (Element Msg)
groupByDay zone now theme items =
    let
        sortedItems =
            List.sortBy
                (\item ->
                    case item.pubDate of
                        Just pd ->
                            Time.posixToMillis pd

                        Nothing ->
                            0
                )
                items
                |> List.reverse

        groups =
            groupByDayHelp zone [] sortedItems
    in
    List.map (daySection zone now theme) groups


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


daySection : Zone -> Posix -> Theme -> DayGroup -> Element Msg
daySection zone now theme dayGroup =
    column
        [ width fill
        , spacing 12
        ]
        [ dayHeader zone now theme dayGroup.date
        , column
            [ width fill
            , spacing 8
            ]
            (List.map (timelineItem now theme) dayGroup.items)
        ]


dayHeader : Zone -> Posix -> Theme -> Posix -> Element Msg
dayHeader zone now theme date =
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

        mutedTxt =
            mutedColor theme

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
    in
    el
        [ Font.size 13
        , Font.medium
        , Font.color mutedTxt
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


timelineItem : Posix -> Theme -> TimelineItem -> Element Msg
timelineItem now theme item =
    let
        txtColor =
            textColor theme

        mutedTxt =
            mutedColor theme

        cardBg =
            cardColor theme

        border =
            borderColor theme
    in
    column
        [ width fill
        , spacing 4
        , padding 12
        , Background.color cardBg
        , Border.rounded 8
        , Border.width 1
        , Border.color border
        ]
        [ row
            [ spacing 8
            , width fill
            ]
            [ if item.favicon /= "" then
                image
                    [ width (px 16)
                    , height (px 16)
                    , Border.rounded 2
                    ]
                    { src = item.favicon, description = item.feedTitle ++ " favicon" }

              else
                Element.none
            , el
                [ Font.size 12
                , Font.color mutedTxt
                ]
                (text item.feedTitle)
            , el [ alignRight ] (text (relativeTime now item.pubDate))
            ]
        , paragraph
            [ Font.size 15
            , Font.color txtColor
            , htmlAttribute (Html.Attributes.style "word-break" "break-word")
            , htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
            , width fill
            ]
            [ link
                [ Font.color txtColor
                , htmlAttribute (Html.Attributes.style "text-decoration" "none")
                ]
                { url = item.link, label = text item.title }
            ]
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

            else
                formatDate Time.utc (Time.millisToPosix pubMillis)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
