module Pages.Timeline exposing (Model, Msg(..), init, subscriptions, update, view)

import Api exposing (Cluster, TimelineItem, clusterItemsFromTimeline, fetchTimeline)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes
import Http
import Process
import Task
import Set exposing (Set)
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (borderColor, cardColor, dayHeaderBg, errorColor, lumeOrange, mutedColor, surfaceColor, textColor)
import ThemeTypography as Ty
import Time exposing (Posix, Zone, toDay, toMonth, toYear)
import Json.Decode as Decode
import Pages.ViewIcon exposing (viewIcon)
import Responsive exposing (Breakpoint, breakpointFromWidth, isMobile, isVeryNarrow, horizontalPadding, verticalPadding, containerMaxWidth, timelineTimeColumnWidth, timelineClusterPadding)


parseHexColor : String -> Maybe Element.Color
parseHexColor input =
    let
        cleanInput =
            String.trim input
    in
    case cleanInput of
        _ ->
            if String.startsWith "#" cleanInput then
                parseHexClean (String.replace "#" "" cleanInput)

            else if String.startsWith "rgb(" cleanInput then
                parseRgb cleanInput

            else
                Nothing


parseHexClean : String -> Maybe Element.Color
parseHexClean cleanHex =
    case String.length cleanHex of
        6 ->
            let
                r =
                    String.slice 0 2 cleanHex |> String.toInt |> Maybe.withDefault 0
                g =
                    String.slice 2 4 cleanHex |> String.toInt |> Maybe.withDefault 0
                b =
                    String.slice 4 6 cleanHex |> String.toInt |> Maybe.withDefault 0
            in
            Just (rgb255 r g b)

        3 ->
            let
                r =
                    String.slice 0 1 cleanHex |> (\x -> x ++ x) |> String.toInt |> Maybe.withDefault 0
                g =
                    String.slice 1 2 cleanHex |> (\x -> x ++ x) |> String.toInt |> Maybe.withDefault 0
                b =
                    String.slice 2 3 cleanHex |> (\x -> x ++ x) |> String.toInt |> Maybe.withDefault 0
            in
            Just (rgb255 r g b)

        _ ->
            Nothing


parseRgb : String -> Maybe Element.Color
parseRgb input =
    let
        withoutRgb =
            String.dropLeft 4 input |> String.dropRight 1

        parts =
            String.split "," withoutRgb |> List.map String.trim
    in
    case parts of
        [ rStr, gStr, bStr ] ->
            case ( String.toInt rStr, String.toInt gStr, String.toInt bStr ) of
                ( Just r, Just g, Just b ) ->
                    Just (rgb255 r g b)

                _ ->
                    Nothing

        _ ->
            Nothing


getFeedTitleColor : Shared.Theme -> String -> String -> Element.Color
getFeedTitleColor theme headerColor headerTextColor =
    case parseColor headerTextColor of
        Just textColor ->
            textColor

        Nothing ->
            case parseColor headerColor of
                Just _ ->
                    textColorFromBg headerColor

                Nothing ->
                    mutedColor theme


textColorFromBg : String -> Element.Color
textColorFromBg bgColor =
    let
        parseRgbValues str =
            let
                clean = String.replace "rgb(" "" str |> String.replace ")" "" |> String.replace " " ""
                parts = String.split "," clean
            in
            case parts of
                r :: g :: b :: [] ->
                    case (String.toInt r, String.toInt g, String.toInt b) of
                        (Just ri, Just gi, Just bi) ->
                            Just (ri, gi, bi)
                        _ ->
                            Nothing
                _ ->
                    Nothing

        luminance =
            case parseRgbValues bgColor of
                Just (r, g, b) ->
                    ((toFloat r * 299) + (toFloat g * 587) + (toFloat b * 114)) / 1000
                Nothing ->
                    0
    in
    if luminance >= 128 then
        rgb255 31 41 35
    else
        rgb255 255 255 255


textColorFromBgString : String -> String
textColorFromBgString bgColor =
    let
        parseRgbValues str =
            let
                clean = String.replace "rgb(" "" str |> String.replace ")" "" |> String.replace " " ""
                parts = String.split "," clean
            in
            case parts of
                r :: g :: b :: [] ->
                    case (String.toInt r, String.toInt g, String.toInt b) of
                        (Just ri, Just gi, Just bi) ->
                            Just (ri, gi, bi)
                        _ ->
                            Nothing
                _ ->
                    Nothing

        luminance =
            case parseRgbValues bgColor of
                Just (r, g, b) ->
                    ((toFloat r * 299) + (toFloat g * 587) + (toFloat b * 114)) / 1000
                Nothing ->
                    0
    in
    if luminance >= 128 then
        "rgb(31,55,35)"
    else
        "rgb(255,255,255)"


{-| Theme-aware readable color selection

    Compute which text color (light or dark) will be most readable against a
    given background color, taking the current UI theme into account and
    preferring colors that meet WCAG contrast >= 4.5:1 when possible.
-}

getRgbTupleFromString : String -> Maybe ( Int, Int, Int )
getRgbTupleFromString str =
    let
        clean = String.trim str
        withoutRgb = String.dropLeft 4 str |> String.dropRight 1
        hex = String.replace "#" "" clean
    in
    if String.startsWith "rgb(" clean then
        let
            parts = String.split "," (String.replace "rgb(" "" (String.replace ")" "" clean)) |> List.map String.trim
        in
        case parts of
            [ r, g, b ] ->
                case ( String.toInt r, String.toInt g, String.toInt b ) of
                    ( Just ri, Just gi, Just bi ) -> Just ( ri, gi, bi )
                    _ -> Nothing

            _ ->
                Nothing

    else if String.length hex == 6 then
        case ( String.toInt (String.slice 0 2 hex), String.toInt (String.slice 2 4 hex), String.toInt (String.slice 4 6 hex) ) of
            ( Just ri, Just gi, Just bi ) ->
                Just ( ri, gi, bi )

            _ ->
                Nothing

    else
        Nothing


srgbChannelLinear : Int -> Float
srgbChannelLinear c =
    let
        v = toFloat c / 255
    in
    if v <= 0.03928 then
        v / 12.92
    else
        ((v + 0.055) / 1.055) ^ 2.4


relativeLuminance : ( Int, Int, Int ) -> Float
relativeLuminance ( r, g, b ) =
    0.2126 * srgbChannelLinear r + 0.7152 * srgbChannelLinear g + 0.0722 * srgbChannelLinear b


contrastRatio : ( Int, Int, Int ) -> ( Int, Int, Int ) -> Float
contrastRatio fg bg =
    let
        lf = relativeLuminance fg
        lb = relativeLuminance bg
        ( l1, l2 ) = if lf > lb then ( lf, lb ) else ( lb, lf )
    in
    (l1 + 0.05) / (l2 + 0.05)


readableColorForTheme : String -> Shared.Theme -> String
readableColorForTheme bgStr theme =
    case getRgbTupleFromString bgStr of
        Nothing ->
            -- Fallback to dark text if we can't parse the bg
            "rgb(31,41,35)"

        Just bg ->
            let
                white = ( 255, 255, 255 )
                dark = ( 31, 41, 35 )
                contrastWhite = contrastRatio white bg
                contrastDark = contrastRatio dark bg
            in
            case theme of
                Shared.Light ->
                    if contrastDark >= 4.5 then
                        "rgb(31,41,35)"
                    else if contrastWhite >= 4.5 then
                        "rgb(255,255,255)"
                    else if contrastDark >= contrastWhite then
                        "rgb(31,41,35)"
                    else
                        "rgb(255,255,255)"

                Shared.Dark ->
                    if contrastWhite >= 4.5 then
                        "rgb(255,255,255)"
                    else if contrastDark >= 4.5 then
                        "rgb(31,41,35)"
                    else if contrastWhite >= contrastDark then
                        "rgb(255,255,255)"
                    else
                        "rgb(31,41,35)"


parseColor : String -> Maybe Element.Color
parseColor input =
    parseHexColor input


-- Helpers to extract theme-aware colors from server-provided JSON
themeTextFor : Maybe Decode.Value -> Shared.Theme -> Maybe String
themeTextFor maybeVal theme =
    case maybeVal of
        Nothing ->
            Nothing

        Just v ->
                -- Honor server-provided theme values when the server marked them
                -- as either `auto-corrected` or `auto`. We still validate contrast
                -- later (see `themeTextSafe`) so accepting `auto` here allows the
                -- UI to use server colors when they are present and safe.
                let
                    decodeSource = Decode.field "source" (Decode.nullable Decode.string)
                    srcRes = Decode.decodeValue decodeSource v
                    sourceOk =
                        case srcRes of
                        Ok (Just s) -> s == "auto-corrected" || s == "auto"
                        _ -> False
            in
            if not sourceOk then
                Nothing
            else
                let
                    decodeLight = Decode.field "text" (Decode.field "light" (Decode.nullable Decode.string))
                    decodeDark = Decode.field "text" (Decode.field "dark" (Decode.nullable Decode.string))
                    lightRes = Decode.decodeValue decodeLight v
                    darkRes = Decode.decodeValue decodeDark v
                    light = case lightRes of
                        Ok l -> l
                        Err _ -> Nothing
                    dark = case darkRes of
                        Ok d -> d
                        Err _ -> Nothing
                in
                case theme of
                    Shared.Dark ->
                        case dark of
                            Just d -> Just d
                            Nothing -> light

                    Shared.Light ->
                        case light of
                            Just l -> Just l
                            Nothing -> dark


themeBgFor : Maybe Decode.Value -> Maybe String
themeBgFor maybeVal =
    case maybeVal of
        Nothing ->
            Nothing

        Just v ->
            -- Only return background when server provided an auto-corrected theme
            case Decode.decodeValue (Decode.field "source" (Decode.nullable Decode.string)) v of
                Ok (Just s) ->
                    if s == "auto-corrected" then
                        case Decode.decodeValue (Decode.field "bg" (Decode.nullable Decode.string)) v of
                            Ok bg -> bg
                            Err _ -> Nothing
                    else
                        Nothing

                _ ->
                    Nothing


themeTextSafe : Maybe Decode.Value -> Shared.Theme -> String -> Maybe String
themeTextSafe maybeVal theme bgStr =
    case themeTextFor maybeVal theme of
        Nothing ->
            Nothing

        Just t ->
            case ( getRgbTupleFromString t, getRgbTupleFromString bgStr ) of
                ( Just fg, Just bg ) ->
                    if contrastRatio fg bg >= 4.5 then
                        Just t
                    else
                        Nothing

                _ ->
                    Nothing


type alias Model =
    { items : List TimelineItem
    , clusters : List Cluster
    , expandedClusters : Set String
    , loading : Bool
    , loadingMore : Bool
    , error : Maybe String
    , hasMore : Bool
    , offset : Int
    , insertedIds : Set String
    , sentinelNear : Bool
    , isClustering : Bool
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
      , insertedIds = Set.empty
      , sentinelNear = False
      , isClustering = False
      }
    , fetchTimeline 35 0 GotTimeline
    )


type Msg
    = GotTimeline (Result Http.Error Api.TimelineResponse)
    | GotMoreTimeline (Result Http.Error Api.TimelineResponse)
    | LoadMore
    | ClearInserted
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
                , isClustering = response.isClustering
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
                existingIds =
                    model.items |> List.map .id |> Set.fromList

                newItemsFromResponse =
                    response.items |> List.filter (\it -> not (Set.member it.id existingIds))

                -- Append new items to existing - backend returns already sorted items
                -- No resort needed to avoid scroll position jumps
                newItems =
                    model.items ++ newItemsFromResponse

                newClusters =
                    clusterItemsFromTimeline newItems

                addedIds =
                    newItemsFromResponse |> List.map .id |> Set.fromList
            in
            ( { model
                | items = newItems
                , clusters = newClusters
                , loadingMore = False
                , hasMore = response.hasMore
                , offset = model.offset + List.length newItemsFromResponse
                , insertedIds = Set.union model.insertedIds addedIds
                , isClustering = response.isClustering
              }
            , Task.perform (\_ -> ClearInserted) (Process.sleep 300)
            )

        GotMoreTimeline (Err _) ->
            ( { model
                | loadingMore = False
              }
            , Cmd.none
            )

        LoadMore ->
            ( { model | loadingMore = True }
            , fetchTimeline 500 model.offset GotMoreTimeline
            )

        ClearInserted ->
            ( { model | insertedIds = Set.empty }
            , Cmd.none
            )

        NearBottom nearBottom ->
            let
                newModel = { model | sentinelNear = nearBottom }
            in
            if nearBottom && model.hasMore && not model.loadingMore && not model.loading then
                ( { newModel | loadingMore = True }
                , fetchTimeline 500 model.offset GotMoreTimeline
                )

            else
                ( newModel, Cmd.none )

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

        breakpoint =
            Responsive.breakpointFromWidth shared.windowWidth

        horizontalPadding =
            Responsive.horizontalPadding breakpoint

        verticalPadding =
            Responsive.verticalPadding breakpoint

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
          , Background.color bg
         , Font.color txtColor
         , htmlAttribute (Html.Attributes.attribute "data-timeline-page" "true")
         , htmlAttribute (Html.Attributes.class "auto-hide-scroll")
         ]
          [ el
                [ width fill
                , height (px 2)
                , Background.color (case shared.theme of
                    Shared.Dark -> rgb255 100 100 100
                    Shared.Light -> rgb255 200 200 200
                  )
                ]
                Element.none
          
          , if model.loading && List.isEmpty model.clusters then
            el
                [ centerX
                , centerY
                , Ty.body
                , Font.color mutedTxt
                ]
                (text "Loading...")

          else if model.error /= Nothing then
            el
                [ centerX
                , centerY
                , Ty.body
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
                    (List.concatMap (dayClusterSection breakpoint shared.zone shared.now theme model.expandedClusters model.insertedIds) clustersByDay)
                , el [ htmlAttribute (Html.Attributes.id "scroll-sentinel"), height (px 1), width fill ] (text "")
                , if model.loadingMore then
                    el [ centerX, padding 12 ] (text "Loading...")
                  else if not model.hasMore then
                    el [ centerX, padding 12, Font.color mutedTxt ] (text "End of feed")
                  else
                    let
                        bgColor =
                            case theme of
                                Shared.Dark ->
                                    "rgb(51, 65, 85)"

                                Shared.Light ->
                                    "rgb(241, 245, 249)"

                        textColor =
                            case theme of
                                Shared.Dark ->
                                    "rgb(248, 250, 252)"

                                Shared.Light ->
                                    "rgb(100, 116, 139)"
                     in
                     let
                         maybeBg = parseColor bgColor
                         maybeText = parseColor textColor
                         baseAttrs =
                             [ centerX
                             , paddingXY 4 12
                             , Border.rounded 6
                             , Ty.small
                             , Font.medium
                             , htmlAttribute (Html.Attributes.class "qh-load-more")
                             , Border.color (rgba 0 0 0 0.08)
                             , htmlAttribute (Html.Attributes.attribute "data-load-more" "true")
                             ]
                         loadMoreAttrs =
                             baseAttrs
                                 ++ (case maybeBg of
                                         Just c -> [ Background.color c ]
                                         Nothing -> [])
                                 ++ (case maybeText of
                                         Just c -> [ Font.color c ]
                                         Nothing -> [])
                     in
                     Input.button
                         loadMoreAttrs
                         { onPress = Just LoadMore
                         , label = text "Load More"
                         }
                ]
            ]


type alias DayClusterGroup =
    { date : Posix
    , clusters : List Cluster
    }


groupClustersByDay : Zone -> Posix -> List Cluster -> List DayClusterGroup
groupClustersByDay zone now clusters =
    let
        -- API returns newest -> oldest, preserve that order
        sortedClusters =
            clusters

        groups =
            groupClustersByDayHelp zone [] sortedClusters

        monthToInt : Time.Month -> Int
        monthToInt m =
            case m of
                Time.Jan -> 1
                Time.Feb -> 2
                Time.Mar -> 3
                Time.Apr -> 4
                Time.May -> 5
                Time.Jun -> 6
                Time.Jul -> 7
                Time.Aug -> 8
                Time.Sep -> 9
                Time.Oct -> 10
                Time.Nov -> 11
                Time.Dec -> 12

        -- Sort days: newest day first
        sortedGroups =
            List.sortWith
                (\( ( y1, m1, d1 ), _ ) ( ( y2, m2, d2 ), _ ) ->
                    if y1 == y2 then
                        if m1 == m2 then
                            Basics.compare d2 d1
                        else
                            Basics.compare (monthToInt m2) (monthToInt m1)
                    else
                        Basics.compare y2 y1
                )
                groups
    in
    -- Keep clusters within each day in API order (newest -> oldest), reverse each day's clusters to match
    List.map
        (\( key, dayClusters ) ->
            { date = getClusterDateFromKey zone key dayClusters
            , clusters = List.reverse dayClusters
            }
        )
        sortedGroups


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


dayClusterSection : Responsive.Breakpoint -> Zone -> Posix -> Theme -> Set String -> Set String -> DayClusterGroup -> List (Element Msg)
dayClusterSection breakpoint zone now theme expandedClusters insertedIds dayGroup =
    [ dayHeader breakpoint zone now theme dayGroup.date
    , column
        [ width fill
        , spacing 0
        , paddingEach { top = 24, bottom = 32, left = 0, right = 0 }
        ]
        (List.map (clusterItem breakpoint zone now theme expandedClusters insertedIds) dayGroup.clusters)
    ]


dayHeader : Responsive.Breakpoint -> Zone -> Posix -> Theme -> Posix -> Element Msg
dayHeader breakpoint zone now theme date =
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

        headerTextDisplay =
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
    row
        [ spacing 12
        , paddingXY 16 12
        , htmlAttribute (Html.Attributes.attribute "data-timeline-header" "true")
        , htmlAttribute (Html.Attributes.style "transition" "transform .20s ease-out, opacity .20s ease-out")
        ]
        [ el
            [ width (px 8)
            , height (px 8)
            , Background.color Theme.lumeOrange
            , Border.rounded 999
            , centerY
            ]
            Element.none
        , el
            [ Background.color (dayHeaderBg theme)
            , Border.rounded 999
            , paddingXY 8 12
            ]
            (el
                (Ty.dayHeader breakpoint
                    ++ [ Font.color (textColor theme) ]
                )
                (text headerTextDisplay)
            )
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


clusteringIndicator : Bool -> Element msg
clusteringIndicator isClustering =
    if isClustering then
        row
            [ spacing 2
            , htmlAttribute (Html.Attributes.class "clustering-indicator")
            , htmlAttribute (Html.Attributes.title "Story clustering in progress...")
            ]
            [ el [ htmlAttribute (Html.Attributes.class "clustering-dot") ] (text ".")
            , el [ htmlAttribute (Html.Attributes.class "clustering-dot") ] (text ".")
            , el [ htmlAttribute (Html.Attributes.class "clustering-dot") ] (text ".")
            ]

    else
        Element.none


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


clusterItem : Responsive.Breakpoint -> Time.Zone -> Time.Posix -> Theme -> Set String -> Set String -> Cluster -> Element Msg
clusterItem breakpoint zone now theme expandedClusters insertedIds cluster =
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

        headerTextColor =
            Maybe.withDefault "" cluster.representative.headerTextColor

        headerColor =
            Maybe.withDefault "" cluster.representative.headerColor

        -- Theme-aware JSON (if provided by server)
        headerTheme =
            cluster.representative.headerTheme
    in
    let
        isExpanded =
            Set.member cluster.id expandedClusters

        isInserted =
            Set.member cluster.representative.id insertedIds
    in
    let
        baseAttrs =
            [ width fill
            , spacing 8
            , alignTop
            , paddingEach { top = 8, bottom = 8, left = 8, right = 8 }
            , htmlAttribute (Html.Attributes.attribute "data-timeline-item" "true")
            ]

        rowAttrs =
            if isInserted then
                baseAttrs ++ [ htmlAttribute (Html.Attributes.class "timeline-inserted") ]
            else
                baseAttrs
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
         [ row rowAttrs
             [ el
                  [ width (px (Responsive.timelineTimeColumnWidth breakpoint))
                 , Ty.meta
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
                [ paragraph [ width fill, Ty.size13 ]
                (let
                    -- Determine background color (prefer theme-aware, fallback to legacy)
                    effectiveBg =
                        case themeBgFor headerTheme of
                            Just bg -> bg
                            Nothing -> headerColor

                    -- Determine text colors (contrast-safe selection)
                    titleTextColor =
                        case themeTextSafe headerTheme theme effectiveBg of
                            Just t -> t
                            Nothing ->
                                -- If server provided a header_text_color, validate its contrast
                                if headerTextColor /= "" then
                                    case ( getRgbTupleFromString headerTextColor, getRgbTupleFromString effectiveBg ) of
                                        ( Just fg, Just bg ) ->
                                            if contrastRatio fg bg >= 4.5 then
                                                headerTextColor
                                            else
                                                -- fallback to readable color computed from bg
                                                readableColorForTheme effectiveBg theme

                                        -- Could not parse one of the colors: fallback to readableColorForTheme
                                        _ -> readableColorForTheme effectiveBg theme

                                else if headerColor /= "" then
                                    readableColorForTheme headerColor theme
                                else
                                    -- final fallback: readable color for effectiveBg
                                    readableColorForTheme effectiveBg theme

                    linkTextColor =
                        case themeTextSafe headerTheme theme effectiveBg of
                            Just t -> t
                            Nothing ->
                                if headerTextColor /= "" then
                                    case ( getRgbTupleFromString headerTextColor, getRgbTupleFromString effectiveBg ) of
                                        ( Just fg, Just bg ) ->
                                            if contrastRatio fg bg >= 4.5 then
                                                headerTextColor
                                            else
                                                readableColorForTheme effectiveBg theme
                                        _ -> readableColorForTheme effectiveBg theme
                                else if headerColor /= "" then
                                    readableColorForTheme headerColor theme
                                else
                                    readableColorForTheme effectiveBg theme

                    -- Title element with background pill
                    titleAttrs =
                        let
                            computedColor =
                                case parseColor titleTextColor of
                                    Just c -> c
                                    Nothing -> case parseColor (textColorFromBgString effectiveBg) of
                                        Just c2 -> c2
                                        Nothing -> textColor theme
                        in
                        if headerColor /= "" || headerTextColor /= "" || headerTheme /= Nothing then
                            [ Font.size 12
                            , Font.color computedColor
                            , htmlAttribute (Html.Attributes.attribute "data-server-header-text-color" titleTextColor)
                            , htmlAttribute (Html.Attributes.attribute "data-use-server-colors" "true")
                            ]
                        else
                            [ Font.size 12
                            -- Use a data attribute for fallback colors so client-side
                            -- CSS/JS can apply them deterministically (avoids inline style races).
                            , htmlAttribute (Html.Attributes.attribute "data-server-fallback-color" titleTextColor)
                            , Font.color computedColor
                            ]

                    titleBgAttrs =
                        case parseColor effectiveBg of
                            Just c ->
                                [ Background.color c
                                , paddingXY 2 6
                                , Border.rounded 6
                                ]

                            Nothing ->
                                []

                    -- Link attributes
                    linkAttrs =
                        let
                            computedLinkColor =
                                case parseColor linkTextColor of
                                    Just c -> c
                                    Nothing -> case parseColor (textColorFromBgString effectiveBg) of
                                        Just c2 -> c2
                                        Nothing -> textColor theme
                        in
                        (if headerColor /= "" || headerTextColor /= "" || headerTheme /= Nothing then
                            [ htmlAttribute (Html.Attributes.attribute "data-display-link" "true")
                            , Font.semiBold
                            , Font.color computedLinkColor
                            , mouseOver [ Font.color lumeOrange ]
                            , htmlAttribute (Html.Attributes.attribute "data-server-header-text-color" linkTextColor)
                            , htmlAttribute (Html.Attributes.attribute "data-use-server-colors" "true")
                            ]
                         else
                            [ htmlAttribute (Html.Attributes.attribute "data-display-link" "true")
                            , Font.semiBold
                            , Font.color computedLinkColor
                            , mouseOver [ Font.color lumeOrange ]
                            , htmlAttribute (Html.Attributes.attribute "data-server-fallback-color" linkTextColor)
                            ])
                  in
                  [ faviconImg
                  , el ( [ Ty.meta ] ++ titleAttrs ++ titleBgAttrs ) (text cluster.representative.feedTitle)
                  , el [ Font.color mutedTxt, paddingXY 4 0 ] (text "•")
                  , link linkAttrs { url = cluster.representative.link, label = text cluster.representative.title }
                  , (if cluster.count > 1 then
                        Input.button
                            [ paddingEach { top = 0, right = 0, bottom = 0, left = 8 }
                            , Font.color (if isExpanded then lumeOrange else mutedTxt)
                            , mouseOver [ Font.color lumeOrange ]
                            ]
                            { onPress = Just (ToggleCluster cluster.id)
                            , label = text (" ↩ " ++ String.fromInt cluster.count)
                            }
                      else
                        Element.none)
                  ] )
                ]
            ]
        , if clusterCount > 1 && isExpanded then
             column
                 [ width fill
                 , spacing 8
                  , paddingEach { top = 0, bottom = 12, left = (Responsive.timelineClusterPadding breakpoint), right = 8 }
                 ]
                 (List.map (\it -> clusterOtherItem now theme it) cluster.others)
          else
            Element.none
        ]


clusterOtherItem now theme item =
    let
        mutedTxt =
            mutedColor theme

        itemHeaderColor =
            Maybe.withDefault "" item.headerColor

        itemHeaderTextColor =
            Maybe.withDefault "" item.headerTextColor

        faviconImg =
            Maybe.map
                (\faviconUrl ->
                    viewIcon faviconUrl item.feedTitle
                )
                item.favicon
                |> Maybe.withDefault (text "")
    in
         paragraph
        [ width fill
        , paddingEach { top = 4, bottom = 4, left = 0, right = 0 }
        , htmlAttribute (Html.Attributes.attribute "data-timeline-item" "true")
        , Background.color (rgba 0 0 0 0)
        , Font.color (textColor theme)
        ]
        [ faviconImg
        , el [ Ty.meta
             -- Prefer data attributes for header text colors instead of inline styles
             , (if itemHeaderTextColor /= "" || itemHeaderColor /= "" then
                    htmlAttribute (Html.Attributes.attribute "data-server-header-text-color" (if itemHeaderTextColor /= "" then itemHeaderTextColor else textColorFromBgString itemHeaderColor))
                else
                    htmlAttribute (Html.Attributes.attribute "data-server-fallback-color"
                        (case theme of
                            Dark -> "rgb(255, 255, 255)"
                            Light -> "rgb(17, 24, 39)"
                        )
                    )
               )
           , Font.color (getFeedTitleColor theme itemHeaderColor itemHeaderTextColor)
          ]
             (text item.feedTitle)
        , el [ Ty.meta, Font.color mutedTxt, paddingXY 4 0 ] (text "•")
         , let
            otherLinkBase = [ Font.size 11, htmlAttribute (Html.Attributes.attribute "data-display-link" "true"), Font.medium, mouseOver [ Font.color lumeOrange ] ]
            otherLinkAttrs =
                if itemHeaderTextColor /= "" || itemHeaderColor /= "" then
                    [ htmlAttribute (Html.Attributes.attribute "data-server-header-text-color" (if itemHeaderTextColor /= "" then itemHeaderTextColor else textColorFromBgString itemHeaderColor))
                    , htmlAttribute (Html.Attributes.attribute "data-use-server-colors" "true")
                    ]
                else
                    let
                        defaultLinkColor =
                            case theme of
                                Dark ->
                                    "rgb(248, 250, 252)"
                                
                                Light ->
                                    "rgb(17, 24, 39)"
                    in
                    [ htmlAttribute (Html.Attributes.attribute "data-server-fallback-color" defaultLinkColor) ]
          in
          link (otherLinkBase ++ otherLinkAttrs) { url = item.link, label = text item.title }
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
subscriptions model =
    Sub.none
