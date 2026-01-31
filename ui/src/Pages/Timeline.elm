module Pages.Timeline exposing (Model, Msg(..), init, subscriptions, update, view)

import Api exposing (Cluster, TimelineItem, clusterItemsFromTimeline, fetchTimeline)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes
import Http
import Set exposing (Set)
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (borderColor, cardColor, errorColor, lumeOrange, mutedColor, surfaceColor, textColor)
import Time exposing (Posix, Zone, toDay, toMonth, toYear)
import Pages.ViewIcon exposing (viewIcon)


type alias Model =
    { items : List TimelineItem
    , clusters : List Cluster
    , expandedClusters : Set String
    , loading : Bool
    , loadingMore : Bool
    , error : Maybe String
    , hasMore : Bool
    , offset : Int
    }


init : Shared.Model -> ( Model, Cmd Msg )
init shared =
    ( { items = []
      , clusters = []
      , expandedClusters = Set.empty
      , loading = True
      , loadingMore = False
      , error = Nothing
      , hasMore = True
      , offset = 0
      }
    , fetchTimeline 35 0 GotTimeline
    )


type Msg
    = GotTimeline (Result Http.Error Api.TimelineResponse)
    | GotMoreTimeline (Result Http.Error Api.TimelineResponse)
    | LoadMore
    | ToggleCluster String
    | ToggleTheme
    | NearBottom Bool


update : Shared.Model -> Msg -> Model -> ( Model, Cmd Msg )
update shared msg model =
    case msg of
        GotTimeline (Ok response) ->
            let
                clusters =
                    clusterItemsFromTimeline response.items

                -- Keep API order (items already sorted by pub_date DESC in backend)
                sortedClusters =
                    clusters
            in
            ( { model
                | items = response.items
                , clusters = sortedClusters
                , loading = False
                , error = Nothing
                , hasMore = response.hasMore
                , offset = List.length response.items
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

        GotMoreTimeline (Ok response) ->
            let
                newItems =
                    Api.sortTimelineItems (model.items ++ response.items)

                newClusters =
                    clusterItemsFromTimeline newItems
            in
            ( { model
                | items = newItems
                , clusters = newClusters
                , loadingMore = False
                , hasMore = response.hasMore
                , offset = model.offset + List.length response.items
              }
            , Cmd.none
            )

        GotMoreTimeline (Err _) ->
            ( { model
                | loadingMore = False
              }
            , Cmd.none
            )

        LoadMore ->
            ( { model | loadingMore = True }
            , fetchTimeline 35 model.offset GotMoreTimeline
            )

        NearBottom nearBottom ->
            if nearBottom && model.hasMore && not model.loadingMore then
                update shared LoadMore model

            else
                ( model, Cmd.none )

        ToggleCluster clusterId ->
            let
                newExpanded =
                    if Set.member clusterId model.expandedClusters then
                        Set.remove clusterId model.expandedClusters

                    else
                        Set.insert clusterId model.expandedClusters
            in
            ( { model | expandedClusters = newExpanded }
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
                40

        bg =
            surfaceColor theme

        txtColor =
            textColor theme

        mutedTxt =
            mutedColor theme

        clustersByDay =
            groupClustersByDay shared.zone shared.now model.clusters
    in
    column
        [ width (fill |> maximum 1200)
        , centerX
        , height fill
        , spacing 20
        , padding paddingValue
        , paddingXY paddingValue 60
        , Background.color bg
        , htmlAttribute (Html.Attributes.attribute "data-timeline-page" "true")
        , htmlAttribute (Html.Attributes.class "auto-hide-scroll")
        ]
        [ el
            [ Font.size
                (if isMobile then
                    20

                 else
                    24
                )
            , Font.bold
            , Font.color txtColor
            ]
            (text "Timeline")
        , if model.loading && List.isEmpty model.clusters then
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
                ]
                [ column
                    [ width fill
                    , spacing 16
                    ]
                    (List.concatMap (dayClusterSection shared.zone shared.now theme model.expandedClusters) clustersByDay)
                , el [ htmlAttribute (Html.Attributes.id "scroll-sentinel"), height (px 1), width fill ] (text "")
                ]
        ]


type alias DayClusterGroup =
    { date : Posix
    , clusters : List Cluster
    }


groupClustersByDay : Zone -> Posix -> List Cluster -> List DayClusterGroup
groupClustersByDay zone now clusters =
    let
        -- Keep API order (items already sorted by pub_date DESC in backend)
        sortedClusters =
            clusters

        groups =
            groupClustersByDayHelp zone [] sortedClusters
    in
    List.map (\( key, dayClusters ) -> { date = getClusterDateFromKey zone key dayClusters, clusters = dayClusters }) (List.reverse groups)


groupClustersByDayHelp : Zone -> List ( ( Int, Time.Month, Int ), List Cluster ) -> List Cluster -> List ( ( Int, Time.Month, Int ), List Cluster )
groupClustersByDayHelp zone accum clusters =
    case clusters of
        [] ->
            accum

        cluster :: rest ->
            let
                key =
                    case cluster.representative.pubDate of
                        Just pubDate ->
                            ( toYear zone pubDate, toMonth zone pubDate, toDay zone pubDate )

                        Nothing ->
                            ( 0, Time.Jan, 0 )

                existing =
                    List.filter (\( k, _ ) -> k == key) accum
            in
            case existing of
                ( k, existingClusters ) :: _ ->
                    groupClustersByDayHelp zone
                        (List.map
                            (\( ak, ac ) ->
                                if ak == key then
                                    ( ak, cluster :: ac )

                                else
                                    ( ak, ac )
                            )
                            accum
                        )
                        rest

                [] ->
                    groupClustersByDayHelp zone (( key, [ cluster ] ) :: accum) rest


getClusterDateFromKey : Zone -> ( Int, Time.Month, Int ) -> List Cluster -> Posix
getClusterDateFromKey zone key clusters =
    case clusters of
        [] ->
            Time.millisToPosix 0

        first :: _ ->
            case first.representative.pubDate of
                Just pd ->
                    pd

                Nothing ->
                    Time.millisToPosix 0


dayClusterSection : Zone -> Posix -> Theme -> Set String -> DayClusterGroup -> List (Element Msg)
dayClusterSection zone now theme expandedClusters dayGroup =
    [ dayHeader zone now theme dayGroup.date
    , column
        [ width fill
        , spacing 0
        , paddingEach { top = 16, bottom = 32, left = 0, right = 0 }
        ]
        (List.map (clusterItem zone now theme expandedClusters) dayGroup.clusters)
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

        badgeBg =
            case theme of
                Dark ->
                    rgb255 49 46 129

                -- Indigo 900
                Light ->
                    rgb255 226 232 240

        -- Slate 200
        badgeTxt =
            case theme of
                Dark ->
                    rgb255 224 242 254

                -- Indigo 100
                Light ->
                    rgb255 30 41 59

        -- Slate 800
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
        [ Font.size 20
        , Font.bold
        , Font.color badgeTxt
        , Background.color badgeBg
        , Border.rounded 8
        , padding 8
        , paddingXY 16 8
        , htmlAttribute (Html.Attributes.attribute "data-timeline-header" "true")
        , Element.alignLeft
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


formatTime : Zone -> Posix -> String
formatTime zone date =
    let
        hour =
            Time.toHour zone date

        minute =
            Time.toMinute zone date

        period =
            if hour < 12 then
                "am"

            else
                "pm"

        hour12 =
            let
                h =
                    modBy 12 hour
            in
            if h == 0 then
                12

            else
                h

        mm =
            if minute < 10 then
                "0" ++ String.fromInt minute

            else
                String.fromInt minute
    in
    String.fromInt hour12 ++ ":" ++ mm ++ " " ++ period


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


clusterItem : Time.Zone -> Time.Posix -> Theme -> Set String -> Cluster -> Element Msg
clusterItem zone now theme expandedClusters cluster =
    let
        txtColor =
            textColor theme

        mutedTxt =
            mutedColor theme

        border =
            borderColor theme

        clusterCount =
            cluster.count

        timeStr =
            case cluster.representative.pubDate of
                Just pd ->
                    formatTime zone pd

                Nothing ->
                    "???"

        timeBg =
            case theme of
                Dark ->
                    rgb255 31 41 55

                -- Slate 800
                Light ->
                    rgb255 241 245 249

        -- Slate 100
        timeTxt =
            case theme of
                Dark ->
                    rgb255 203 213 225

                -- Slate 300
                Light ->
                    rgb255 51 65 85

        -- Slate 700
        clusterBg =
            case theme of
                Dark ->
                    rgb255 31 41 55

                Light ->
                    rgb255 248 250 252

        faviconImg =
            Pages.ViewIcon.viewIcon (Maybe.withDefault "" cluster.representative.favicon) cluster.representative.feedTitle
    in
    let
        isExpanded =
            Set.member cluster.id expandedClusters
    in
    column
        [ width fill
        , paddingEach { top = 4, bottom = 4, left = 0, right = 0 }
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        , Border.color border
        , Background.color
            (if isExpanded then
                clusterBg

             else
                rgba 0 0 0 0
            )
        , Border.rounded 8
        ]
        [ row
            [ width fill
            , spacing 12
            , alignTop
            , paddingEach { top = 8, bottom = 8, left = 8, right = 8 }
            , htmlAttribute (Html.Attributes.attribute "data-timeline-item" "true")
            ]
            [ el
                [ width (px 85)
                , Font.size 11
                , Font.color timeTxt
                , Font.family [ Font.monospace ]
                , alignTop
                , paddingXY 6 3
                , Background.color timeBg
                , Border.rounded 4
                , Font.center
                ]
                (text timeStr)
            , column
                [ width fill
                , spacing 0
                , alignTop
                , Font.color txtColor
                ]
                [ -- group favicon + feed title + title together so they wrap naturally
                  paragraph [ spacing 8, width fill, Font.size 11 ]
                      [ el [ centerY, paddingEach { top = 0, right = 6, bottom = 0, left = 0 }, htmlAttribute (Html.Attributes.style "display" "inline-flex") ] faviconImg
                      , el [ Font.color mutedTxt, centerY, htmlAttribute (Html.Attributes.style "display" "inline") ] (text cluster.representative.feedTitle)
                      , el [ Font.color mutedTxt, paddingXY 4 0, centerY, htmlAttribute (Html.Attributes.style "display" "inline") ] (text "•")
                      , link
                          [ htmlAttribute (Html.Attributes.style "text-decoration" "none")
                          , htmlAttribute (Html.Attributes.style "color" "inherit")
                          , htmlAttribute (Html.Attributes.attribute "data-display-link" "true")
                          , mouseOver [ Font.color lumeOrange ]
                          , Font.semiBold
                          , htmlAttribute (Html.Attributes.style "display" "inline")
                          ]
                          { url = cluster.representative.link, label = text cluster.representative.title }
                      , if cluster.count > 1 then
                            Input.button
                                [ paddingEach { top = 0, right = 0, bottom = 0, left = 8 }
                                , Font.color (if isExpanded then lumeOrange else mutedTxt)
                                , mouseOver [ Font.color lumeOrange ]
                                , htmlAttribute (Html.Attributes.style "display" "inline-flex")
                                , centerY
                                ]
                                { onPress = Just (ToggleCluster cluster.id)
                                , label = text (" ↩ " ++ String.fromInt cluster.count)
                                }
                        else
                            Element.none
                      ]
                ]
            ]
        , if clusterCount > 1 && isExpanded then
            column
                [ width fill
                , spacing 8
                , paddingEach { top = 0, bottom = 12, left = 105, right = 8 }
                ]
                (List.map (\it -> clusterOtherItem now theme it) cluster.others)
          else
            Element.none
        ]


clusterOtherItem now theme item =
    let
        txtColor =
            textColor theme

        mutedTxt =
            mutedColor theme

        faviconImg =
            Maybe.map
                (\faviconUrl ->
                    viewIcon faviconUrl item.feedTitle
                )
                item.favicon
                |> Maybe.withDefault Element.none
    in
    paragraph
        [ width fill
        , paddingEach { top = 4, bottom = 4, left = 0, right = 0 }
        ]
        [ el [ centerY, paddingEach { top = 0, right = 8, bottom = 0, left = 0 }, htmlAttribute (Html.Attributes.style "display" "inline-flex") ] faviconImg
        , el [ Font.size 11, Font.color mutedTxt, centerY, htmlAttribute (Html.Attributes.style "display" "inline") ] (text item.feedTitle)
        , el [ Font.size 11, Font.color mutedTxt, paddingXY 4 0, centerY, htmlAttribute (Html.Attributes.style "display" "inline") ] (text "•")
        , link
            [ Font.size 11
            , htmlAttribute (Html.Attributes.style "text-decoration" "none")
            , Font.color txtColor
            , htmlAttribute (Html.Attributes.attribute "data-display-link" "true")
            , mouseOver [ Font.color lumeOrange ]
            , Font.medium
            , htmlAttribute (Html.Attributes.style "display" "inline")
            ]
            { url = item.link, label = text item.title }
        ]


relativeTime : Time.Posix -> Time.Zone -> Maybe Time.Posix -> String
relativeTime now zone maybePubDate =
    case maybePubDate of
        Nothing ->
            "unknown"

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
                "0m"

            else if diffMinutes < 60 then
                String.fromInt diffMinutes ++ "m"

            else if diffHours < 24 then
                String.fromInt diffHours ++ "h"

            else if diffDays < 7 then
                String.fromInt diffDays ++ "d"

            else
                formatDate zone (Time.millisToPosix pubMillis)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
