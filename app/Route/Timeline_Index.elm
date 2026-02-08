module Pages.Timeline.Index exposing (Model, Msg(..), init, update, view, subscriptions)

{-| Timeline page for elm-pages
  
    This page displays a timeline of articles grouped by day.
    It re-uses the original SPA Timeline logic so we don't
    duplicate implementation.
-}

import Api exposing (TimelineItem, fetchTimeline)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Events as Events
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import Http
import Layouts.Shared as Layout
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (borderColor, cardColor, errorColor, mutedColor, surfaceColor, textColor)
import Time exposing (Posix, Zone, toDay, toMonth, toYear)
import Url


type alias Model =
    { items : List TimelineItem
    , loading : Bool
    , error : Maybe String
    , hasMore : Bool
    }


type Msg
    = GotTimeline (Result Http.Error Api.TimelineResponse)
    | ToggleTheme
    | LoadMore


init : ( Model, Cmd Msg )
init =
    ( { items = []
        , loading = True
        , error = Nothing
        , hasMore = True
        }
    , fetchTimeline 50 GotTimeline
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTimeline (Ok response) ->
            ( { model
                | items = model.items ++ response.items
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

        LoadMore ->
            if model.hasMore then
                ( { model | loading = True }
                , fetchTimeline (model.items |> List.length) GotTimeline
                )

            else
            ( model, Cmd.none )


view : Shared.Model -> Model -> Element Msg
view shared model =
    let
        theme =
            shared.theme

        colors =
            Theme.themeToColors theme

        bg =
            Theme.surfaceColor theme

        isMobile =
            shared.windowWidth < 768

        paddingValue =
            if isMobile then
                16

            else
                24

        txtColor =
            Theme.textColor theme

        muted =
            Theme.mutedColor theme
    in
    column
        [ width fill
        , height fill
        , spacing 20
        , padding paddingValue
        , Background.color bg
        ]
        [ el
            [ centerX
            , centerY
            , Font.size (if isMobile then 20 else 24)
            , Font.bold
            , Font.color muted
            ]
            (text "Timeline")
        , if model.loading then
            el
                [ centerX
                , centerY
                , Font.size 16
                , Font.color muted
                ]
                (text "Loading...")
        else if model.error /= Nothing then
            el
                [ centerX
                , centerY
                , Font.size 16
                , Font.color (errorColor theme)
                ]
                (Maybe.withDefault "" model.error)
        else
            groupByDay shared.zone shared.now theme model.items
        ]


groupByDay : Zone -> Posix -> Theme -> List TimelineItem -> Element Msg
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
                            ( toYear zone pubDate, toMonth zone pubDate, toDay zone pubDate)

                        Nothing ->
                            ( 0, Time.Jan, 0)

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
    let
        nowYear =
            toYear zone now

        nowMonth =
            toMonth zone now

        nowDay =
            toDay zone now

        dateYear =
            toYear zone dayGroup.date

        dateMonth =
            toMonth zone dayGroup.date

        dateDay =
            toDay zone dayGroup.date

        muted =
            Theme.mutedColor theme

        headerText =
            if dateYear == nowYear && dateMonth == nowMonth && dateDay == nowDay then
                "Today"

            else if dateYear == nowYear && dateMonth == nowMonth && dateDay == nowDay - 1 then
                "Yesterday"

            else
                formatDate zone dayGroup.date
    in
    column
        [ width fill
        , spacing 12
        ]
        [ dayHeader zone now theme muted headerText
        , column
            [ width fill
            , spacing 8
            ]
            (List.map (timelineItem now theme) dayGroup.items)
        ]


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
            "01"
        Time.Feb ->
            "02"
        Time.Mar ->
            "03"
        Time.Apr ->
            "04"
        Time.May ->
            "05"
        Time.Jun ->
            "06"
        Time.Jul ->
            "07"
        Time.Aug ->
            "08"
        Time.Sep ->
            "09"
        Time.Oct ->
            "10"
        Time.Nov ->
            "11"
        Time.Dec ->
            "12"


type alias DayGroup =
    { date : Posix
    , items : List TimelineItem
    }


timelineItem : Posix -> Theme -> TimelineItem -> Element Msg
timelineItem now theme item =
    let
        txtColor =
            Theme.textColor theme

        cardBg =
            Theme.cardColor theme

        border =
            Theme.borderColor theme

        muted =
            Theme.mutedColor theme

        now =
            Time.now

        maybePubDate =
            case item.pubDate of
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

                    else
                        String.fromInt diffDays ++ "d"

                Nothing ->
                    ""
    in
    row
        [ width fill
        , spacing 8
        , htmlAttribute (Html.Attributes.style "min-width" "0")
        ]
        [ el
            [ width (px 6)
            , height (px 6)
            , Background.color (rgb255 255 165 0)
            , Border.rounded 3
            ]
        , paragraph
            [ width fill
            , Font.size 15
            , Font.color txtColor
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "line-height" "1.4")
            ]
            [ link
                [ Font.color txtColor
                , htmlAttribute (Html.Attributes.style "text-decoration" "none")
                ]
                { url = item.link, label = text item.title }
            ]
        , if maybePubDate /= "" then
            el
                [ Font.size 12
                , Font.color muted
                ]
                (text maybePubDate)
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
