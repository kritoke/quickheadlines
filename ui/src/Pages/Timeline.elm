module Pages.Timeline exposing (Model, Msg(..), init, update, view, subscriptions)

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
import Theme exposing (cardColor, errorColor, surfaceColor, textColor, mutedColor, borderColor, lumeOrange)
import Time exposing (Posix, toDay, toMonth, toYear, Zone)


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
      , expandedClusters = Set.empty  -- Will expand clusters with count > 1 on first view
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

                -- Auto-expand clusters with more than 1 item
                expanded =
                    List.foldl
                        (\cluster acc ->
                            if cluster.count > 1 then
                                Set.insert cluster.id acc
                            else
                                acc
                        )
                        Set.empty
                        clusters

                -- Keep API order (items already sorted by pub_date DESC in backend)
                sortedClusters =
                    clusters
            in
            ( { model
                | items = response.items
                , clusters = sortedClusters
                , expandedClusters = expanded
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
                    model.items ++ response.items

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
                 96

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
         [ width fill
         , height fill
         , spacing 20
         , padding paddingValue
         , Background.color bg
         , htmlAttribute (Html.Attributes.attribute "data-timeline-page" "true")
         , htmlAttribute (Html.Attributes.class "auto-hide-scroll")
         ]
        [ el
            [ Font.size (if isMobile then 20 else 24)
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
            groupClustersByDayHelp zone [] sortedClusters |> List.reverse
    in
    List.map (\( key, dayClusters ) -> { date = getClusterDateFromKey zone key dayClusters, clusters = dayClusters }) groups


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
                    groupClustersByDayHelp zone (List.map (\( ak, ac ) -> if ak == key then ( ak, cluster :: ac ) else ( ak, ac )) accum) rest

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
        , spacing 8
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

        txtColor =
            case theme of
                Dark ->
                    rgb255 148 163 184

                Light ->
                    rgb255 107 114 128

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
        [ Font.size 18
        , Font.bold
        , Font.color txtColor
        , paddingEach { top = 24, bottom = 12, left = 0, right = 0 }
        , htmlAttribute (Html.Attributes.attribute "data-timeline-header" "true")
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


clusterItem : Time.Zone -> Time.Posix -> Theme -> Set String -> Cluster -> Element Msg
clusterItem zone now theme expandedClusters cluster =
    let
        txtColor =
            textColor theme

        mutedTxt =
            mutedColor theme

        cardBg =
            cardColor theme

        border =
            borderColor theme

        isExpanded =
            Set.member cluster.id expandedClusters

        clusterCount =
            cluster.count

        indicator =
            if clusterCount > 1 then
                el
                    [ Font.size 14
                    , Font.color lumeOrange
                    , Font.bold
                    ]
                    (text "↲")

            else
                Element.none
    in
    column
        [ width fill
        , spacing 4
        , padding 12
        , Background.color cardBg
        , Border.rounded 8
        , Border.width 1
        , Border.color border
        , htmlAttribute (Html.Attributes.attribute "data-timeline-item" "true")
        ]
        [ row
            [ spacing 8
            , width fill
            , Element.alignTop
            ]
            [ indicator
            , Maybe.map
                (\faviconUrl ->
                    image
                        [ width (px 16)
                        , height (px 16)
                        , Border.rounded 2
                        ]
                        { src = faviconUrl, description = "favicon" }
                )
                cluster.representative.favicon
                |> Maybe.withDefault Element.none
            , el
                [ Font.size 12
                , Font.color mutedTxt
                , Element.alignTop
                , Element.paddingXY 0 2
                ]
                (text (relativeTime now zone cluster.representative.pubDate))
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
                { url = cluster.representative.link, label = text cluster.representative.title }
            ]
        , if clusterCount > 1 && not isExpanded then
            Input.button
                [ Font.size 12
                , Font.color lumeOrange
                , paddingXY 0 4
                ]
                { onPress = Just (ToggleCluster cluster.id)
                , label = text ("+" ++ String.fromInt (clusterCount - 1) ++ " more")
                }

          else if clusterCount > 1 && isExpanded then
            column
                [ width fill
                , spacing 4
                , paddingEach { top = 8, bottom = 0, left = 0, right = 0 }
                ]
                [ row
                    [ spacing 4
                    , Font.size 12
                    , Font.color mutedTxt
                    ]
                    [ Input.button
                        [ Font.color lumeOrange
                        ]
                        { onPress = Just (ToggleCluster cluster.id)
                        , label = text "collapse"
                        }
                    , text ("(" ++ String.fromInt (clusterCount - 1) ++ " more)")
                    ]
                , column
                    [ spacing 6
                    , paddingEach { top = 6, bottom = 0, left = 16, right = 0 }
                    ]
                    (List.map (clusterOtherItem now theme) cluster.others)
                ]

          else
            Element.none
        ]


clusterOtherItem : Posix -> Theme -> Api.ClusterItem -> Element Msg
clusterOtherItem now theme item =
    let
        txtColor =
            textColor theme
    in
    row
        [ width fill
        , spacing 6
        , paddingEach { top = 3, bottom = 3, left = 0, right = 0 }
        ]
        [ Maybe.map
            (\faviconUrl ->
                image
                    [ width (px 12)
                    , height (px 12)
                    , Border.rounded 1
                    , Element.alignTop
                    , Element.paddingXY 0 2
                    ]
                    { src = faviconUrl, description = "favicon" }
            )
            item.favicon
            |> Maybe.withDefault Element.none
        , paragraph
            [ Font.size 12
            , Element.width fill
            , htmlAttribute (Html.Attributes.style "line-height" "1.3")
            ]
            [ link
                [ Font.color txtColor
                , htmlAttribute (Html.Attributes.style "text-decoration" "none")
                ]
                { url = item.link, label = text item.title }
            ]
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
