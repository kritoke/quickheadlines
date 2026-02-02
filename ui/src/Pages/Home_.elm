module Pages.Home_ exposing (Model, Msg(..), init, update, view, subscriptions)

import Api exposing (Feed, FeedItem, fetchFeeds, sortFeedItems)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes
import Http
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (cardColor, errorColor, surfaceColor, tabActiveBg, tabActiveText, tabHoverBg, tabInactiveText, textColor, themeToColors)
import ThemeTypography as Ty
import Time
import Task
import Process
import Responsive exposing (Breakpoint(..), breakpointFromWidth, isMobile, uniformPadding, containerMaxWidth)
import Set exposing (Set)


type alias Model =
    { feeds : List Feed
    , tabs : List String
    , activeTab : String
    , loading : Bool
    , error : Maybe String
    , loadingFeed : Maybe String
    , insertedIds : Set String
    , isClustering : Bool
    }


init : Shared.Model -> ( Model, Cmd Msg )
init shared =
    ( { feeds = []
      , tabs = []
      , activeTab = "all"
      , loading = True
      , error = Nothing
      , loadingFeed = Nothing
      , insertedIds = Set.empty
      , isClustering = False
      }
    , fetchFeeds "all" GotFeeds
    )


type Msg
    = GotFeeds (Result Http.Error Api.FeedsResponse)
    | SwitchTab String
    | LoadMoreFeed String
    | GotMoreFeed String (Result Http.Error Api.Feed)
    | ClearInserted


update : Shared.Model -> Msg -> Model -> ( Model, Cmd Msg )
update shared msg model =
    case msg of
        GotFeeds (Ok response) ->
            ( { model
                | feeds = response.feeds
                , tabs = List.map .name response.tabs
                , activeTab = response.activeTab
                , loading = False
                , error = Nothing
                , isClustering = response.isClustering
              }
            , Cmd.none
            )

        GotFeeds (Err _) ->
            ( { model
                | loading = False
                , error = Just "Failed to load feeds"
              }
            , Cmd.none
            )

        SwitchTab tab ->
            ( { model | activeTab = tab, loading = True, feeds = [] }
            , fetchFeeds tab GotFeeds
            )

        LoadMoreFeed url ->
            let
                maybeFeed = List.filter (\f -> f.url == url) model.feeds |> List.head
                offset =
                    case maybeFeed of
                        Just f -> List.length f.items
                        Nothing -> 0
            in
            ( { model | loadingFeed = Just url }
            , Api.fetchFeedMore url 15 offset (\res -> GotMoreFeed url res)
            )

        GotMoreFeed url (Ok response) ->
            let
                -- Existing links for the feed we loaded more for
                maybeFeed = List.filter (\f -> f.url == url) model.feeds |> List.head

                existingLinks =
                    case maybeFeed of
                        Just f -> Set.fromList (List.map .link f.items)
                        Nothing -> Set.empty

                addedLinksList =
                    response.items
                        |> List.filter (\i -> not (Set.member i.link existingLinks))
                        |> List.map .link

                addedSet = Set.fromList addedLinksList

                -- Merge existing items with newly fetched items, sort newest -> oldest,
                -- and deduplicate by link (prefer the newest items).
                dedupeByLink items =
                    let
                        folder item (acc, seen) =
                            if Set.member item.link seen then
                                ( acc, seen )
                            else
                                ( acc ++ [ item ], Set.insert item.link seen )

                        (result, _) = List.foldl folder ([], Set.empty) items
                    in
                    result

                updateFeed f =
                    if f.url == url then
                        let
                            merged = Api.sortFeedItems (f.items ++ response.items)
                            mergedDedup = dedupeByLink merged
                        in
                        { f | items = mergedDedup, totalItemCount = response.totalItemCount }
                    else
                        f
            in
            ( { model | feeds = List.map updateFeed model.feeds, loadingFeed = Nothing, insertedIds = Set.union model.insertedIds addedSet }
            , Task.perform (\_ -> ClearInserted) (Process.sleep 320)
            )

        GotMoreFeed _ (Err _) ->
            ( { model | loadingFeed = Nothing, error = Just "Failed to load feed items" }
            , Cmd.none
            )

        ClearInserted ->
            ( { model | insertedIds = Set.empty }
            , Cmd.none
            )


view : Shared.Model -> Model -> Element Msg
view shared model =
     let
         theme =
             shared.theme

         colors =
             themeToColors theme

         bg =
             surfaceColor theme

         breakpoint =
             Responsive.breakpointFromWidth shared.windowWidth
     in
     column
         [ width fill
         , height fill
         , spacing 20
         , Background.color bg
         , htmlAttribute (Html.Attributes.attribute "data-page" "home")
         ]
         [ tabBar shared model
         , content shared model
         ]


tabBar : Shared.Model -> Model -> Element Msg
tabBar shared model =
     if List.isEmpty model.tabs then
         Element.none

     else
         let
             theme =
                 shared.theme

             colors =
                 themeToColors theme

             breakpoint =
                 Responsive.breakpointFromWidth shared.windowWidth

             border =
                 case theme of
                     Shared.Dark ->
                         rgb255 55 55 55

                     Shared.Light ->
                         rgb255 229 231 235

             isMobile =
                 Responsive.isMobile breakpoint

             tabPadding =
                 if isMobile then 8 else 16

             tabElements =
                 allTab shared model.activeTab :: List.map (tabButton shared model.activeTab) model.tabs ++ [ clusteringIndicator model.isClustering ]
         in
         Element.column
              [ Element.width Element.fill
              , Element.spacing 0
              , Element.paddingEach { top = 16, right = 0, bottom = 0, left = 4 }
              ]
          [ if isMobile then
              row
              [ width fill
              , spacing 6
              , Element.paddingEach { top = 4, right = 4, bottom = 12, left = 4 }
              , htmlAttribute (Html.Attributes.style "overflow-x" "auto")
              , htmlAttribute (Html.Attributes.style "white-space" "nowrap")
              , htmlAttribute (Html.Attributes.style "-webkit-overflow-scrolling" "touch")
              , Element.htmlAttribute (Html.Attributes.style "scrollbar-width" "none")
              , Element.htmlAttribute (Html.Attributes.class "auto-hide-scroll")
              ]
              tabElements
            else
                  wrappedRow
                      [ width fill
                      , spacing 6
                      ]
                      tabElements
              ]


allTab : Shared.Model -> String -> Element Msg
allTab shared activeTab =
     let
         theme =
             shared.theme

         breakpoint =
             Responsive.breakpointFromWidth shared.windowWidth

         isMobile =
             Responsive.isMobile breakpoint

         isActive =
             String.toLower activeTab == "all"

         txtColor =
             if isActive then
                 case theme of
                     Shared.Dark -> rgb255 30 41 59
                     Shared.Light -> rgb255 15 23 42
             else
                 case theme of
                     Shared.Dark ->
                         rgb255 148 163 184
                     Shared.Light ->
                         rgb255 100 116 139

         bgColor =
             if isActive then
                 case theme of
                     Shared.Dark -> rgb255 203 213 225
                     Shared.Light -> rgb255 254 215 0
             else
                 Element.rgba 0 0 0 0

         pad =
             if isMobile then 10 else 16
     in
     Input.button
         [ paddingXY pad 8
         , Ty.small
         , Font.medium
         , Font.color txtColor
         , Background.color bgColor
         , Border.rounded 16
         , htmlAttribute (Html.Attributes.style "cursor" "pointer")
         , htmlAttribute (Html.Attributes.style "outline" "none")
         , htmlAttribute (Html.Attributes.style "flex-shrink" "0")
         , htmlAttribute (Html.Attributes.class "tab-link")
         ]
         { onPress = Just (SwitchTab "All")
         , label = text "All"
         }


tabButton : Shared.Model -> String -> String -> Element Msg
tabButton shared activeTab tab =
     let
         theme =
             shared.theme

         breakpoint =
             Responsive.breakpointFromWidth shared.windowWidth

         isMobile =
             Responsive.isMobile breakpoint

         isActive =
             String.toLower tab == String.toLower activeTab

         txtColor =
             if isActive then
                 case theme of
                     Shared.Dark -> rgb255 30 41 59
                     Shared.Light -> rgb255 15 23 42
             else
                 case theme of
                     Shared.Dark ->
                         rgb255 148 163 184

                     Shared.Light ->
                         rgb255 100 116 139

         bgColor =
             if isActive then
                 case theme of
                     Shared.Dark -> rgb255 203 213 225
                     Shared.Light -> rgb255 254 215 0
             else
                 Element.rgba 0 0 0 0

         pad =
             if isMobile then 10 else 16
     in
     Input.button
         [ paddingXY pad 8
         , Ty.small
         , Font.medium
         , Font.color txtColor
         , Background.color bgColor
         , Border.rounded 16
         , htmlAttribute (Html.Attributes.style "cursor" "pointer")
         , htmlAttribute (Html.Attributes.style "outline" "none")
         , htmlAttribute (Html.Attributes.style "flex-shrink" "0")
         , htmlAttribute (Html.Attributes.class "tab-link")
         ]
         { onPress = Just (SwitchTab tab)
         , label = text tab
         }


clusteringIndicator : Bool -> Element msg
clusteringIndicator isClustering =
    if isClustering then
        row
            [ paddingXY 16 8
            , spacing 2
            , htmlAttribute (Html.Attributes.class "clustering-indicator")
            , htmlAttribute (Html.Attributes.title "Story clustering in progress...")
            ]
            [ el [ htmlAttribute (Html.Attributes.class "clustering-dot") ] (text ".")
            , el [ htmlAttribute (Html.Attributes.class "clustering-dot") ] (text ".")
            , el [ htmlAttribute (Html.Attributes.class "clustering-dot") ] (text ".")
            ]

    else
        Element.none


content : Shared.Model -> Model -> Element Msg
content shared model =
    let
        theme =
            shared.theme

        muted =
            Theme.mutedColor theme
    in
    if model.loading then
        el
            [ centerX
            , centerY
            , Ty.size18
            , Font.color muted
            ]
            (text "Loading...")

    else if model.error /= Nothing then
        el
            [ centerX
            , centerY
            , Ty.size18
            , Font.color errorColor
            ]
            (text "Error loading feeds")

    else
        feedGrid shared model


feedGrid : Shared.Model -> Model -> Element Msg
feedGrid shared model =
    let
         theme =
             shared.theme

         breakpoint =
             Responsive.breakpointFromWidth shared.windowWidth

         columnCount =
             case breakpoint of
                 VeryNarrowBreakpoint ->
                     1

                 MobileBreakpoint ->
                     1

                 TabletBreakpoint ->
                     2

                 DesktopBreakpoint ->
                     3

         gapValue =
             case breakpoint of
                 VeryNarrowBreakpoint ->
                     16

                 MobileBreakpoint ->
                     16

                 TabletBreakpoint ->
                     20

                 DesktopBreakpoint ->
                     24
    in
    column
        [ width fill
        , spacing gapValue
        ]
        (chunkList columnCount model.feeds
            |> List.map
                (\feedRow ->
                    Element.row
                        [ width fill
                        , spacing gapValue
                        ]
                        (List.map (feedCard shared.now theme breakpoint model.loadingFeed model.insertedIds) feedRow)
                )
        )


chunkList : Int -> List a -> List (List a)
chunkList size list =
    if List.isEmpty list then
        []

    else
        let
            ( chunk, rest ) =
                splitAt size list
        in
        chunk :: chunkList size rest


splitAt : Int -> List a -> ( List a, List a )
splitAt n list =
    ( List.take n list, List.drop n list )


feedCard : Time.Posix -> Theme -> Responsive.Breakpoint -> Maybe String -> Set String -> Feed -> Element Msg
feedCard now theme breakpoint loadingFeed insertedIds feed =
    let
        colors =
            themeToColors theme

        cardBg =
            cardColor theme

        border =
            Theme.borderColor theme

        txtColor =
            textColor theme

        scrollAttributes =
            case breakpoint of
                DesktopBreakpoint ->
                    [ htmlAttribute (Html.Attributes.style "max-height" "384px")
                    , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
                    , htmlAttribute (Html.Attributes.style "scrollbar-width" "thin")
                    , htmlAttribute (Html.Attributes.style "scrollbar-color" "rgba(128,128,128,0.3) transparent")
                    , htmlAttribute (Html.Attributes.class "auto-hide-scroll")
                    ]

                TabletBreakpoint ->
                    [ htmlAttribute (Html.Attributes.style "max-height" "352px")
                    , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
                    , htmlAttribute (Html.Attributes.style "scrollbar-width" "thin")
                    , htmlAttribute (Html.Attributes.style "scrollbar-color" "rgba(128,128,128,0.3) transparent")
                    , htmlAttribute (Html.Attributes.class "auto-hide-scroll")
                    ]

                _ ->
                    []

        displayedItems = sortFeedItems feed.items

        isLoadingThisFeed =
            case loadingFeed of
                Just u -> u == feed.url
                Nothing -> False

        btnLabel = if isLoadingThisFeed then text "Loading..." else text "Load More"

        btnOnPress = if isLoadingThisFeed then Nothing else Just (LoadMoreFeed feed.url)

        shouldShowButton =
            List.length feed.items < feed.totalItemCount
            && feed.url /= "software://releases"

        loadMoreButton =
            if shouldShowButton then
                Input.button
                    [ centerX
                    , paddingXY 4 12
                    , Border.rounded 6
                    , Border.width 1
                    , Border.color border
                    , Ty.small
                    , Font.medium
                    , htmlAttribute (Html.Attributes.style "color" "inherit")
                    , htmlAttribute (Html.Attributes.class "qh-load-more")
                    ]
                    { onPress = btnOnPress
                    , label = btnLabel
                    }
            else
                Element.none
    in
    column
        [ width fill
        , height fill
        , Background.color cardBg
        , Border.rounded 12
        , Border.width 1
        , Border.color border
        , spacing 8
        , padding 12
        ]
        [ feedHeader theme feed
        , column
            ([ width fill
             , spacing 4
             ] ++ scrollAttributes)
            (List.map (feedItem now theme insertedIds) displayedItems ++ [ loadMoreButton ])
        ]


feedHeader : Theme -> Feed -> Element Msg
feedHeader theme feed =
    let
        ( headerBg, headerTextColor, adaptiveFlag ) =
            case feed.headerTextColor of
                Just textColor ->
                    case feed.headerColor of
                        Just bgColor ->
                            ( Element.htmlAttribute (Html.Attributes.style "background-color" bgColor)
                            , textColor
                            , []
                            )

                        Nothing ->
                            ( case theme of
                                Dark ->
                                    Background.color (rgb255 30 30 30)

                                Light ->
                                    Background.color (rgb255 243 244 246)
                            , textColor
                            , []
                            )

                Nothing ->
                    case feed.headerColor of
                        Just bgColor ->
                            let
                                luminance rgb =
                                    case rgb of
                                        (r, g, b) ->
                                            ((toFloat r * 299) + (toFloat g * 587) + (toFloat b * 114)) / 1000
                                
                                parseRgb str =
                                    let
                                        clean = String.replace "rgb(" "" str |> String.replace ")" "" |> String.replace " " ""
                                        parts = String.split "," clean
                                    in
                                    case parts of
                                        r :: g :: b :: [] ->
                                            Maybe.map3 (\ri gi bi -> (ri, gi, bi))
                                                (String.toInt r)
                                                (String.toInt g)
                                                (String.toInt b)
                                        _ ->
                                            Nothing
                                
                                calculatedTextColor =
                                    case parseRgb bgColor of
                                        Just rgb ->
                                            if luminance rgb >= 128 then
                                                "rgb(17, 24, 39)"
                                            else
                                                "rgb(255, 255, 255)"
                                        Nothing ->
                                            case theme of
                                                Dark -> "rgb(255, 255, 255)"
                                                Light -> "rgb(17, 24, 39)"
                            in
                            ( Element.htmlAttribute (Html.Attributes.style "background-color" bgColor)
                            , calculatedTextColor
                            , []
                            )

                        Nothing ->
                            ( case theme of
                                Dark ->
                                    Background.color (rgb255 30 30 30)

                                Light ->
                                    Background.color (rgb255 243 244 246)
                            , case theme of
                                Dark ->
                                    "rgb(255, 255, 255)"

                                Light ->
                                    "rgb(17, 24, 39)"
                            , [ htmlAttribute (Html.Attributes.attribute "data-use-adaptive-colors" "true") ]
                            )
    in
    row
        ([ width fill
        , spacing 8
        , htmlAttribute (Html.Attributes.class "feed-header")
        , padding 8
        , Border.rounded 8
        , headerBg
        ] ++ adaptiveFlag)
        [ faviconView theme (Maybe.withDefault "" feed.favicon)
        , column [ spacing 2, htmlAttribute (Html.Attributes.style "flex" "1") ]
            [ link
                [ Font.size 18
                , Font.bold
                , (case headerTextColor of
                    "" -> htmlAttribute (Html.Attributes.style "color" "var(--header-text-color)")
                    _ -> htmlAttribute (Html.Attributes.style "color" headerTextColor))
                , Font.underline
                , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
                ]
                { url = feed.siteLink, label = text feed.title }
            , if feed.displayLink /= "" then
                el
                    [ htmlAttribute (Html.Attributes.attribute "data-display-link" "true")
                    , Ty.size13
                    , (case headerTextColor of
                        "" -> htmlAttribute (Html.Attributes.style "color" "var(--header-text-color)")
                        _ -> htmlAttribute (Html.Attributes.style "color" headerTextColor))
                    , htmlAttribute (Html.Attributes.style "opacity" "0.8")
                    ]
                    (text feed.displayLink)

              else
                Element.none
            ]
        ]


faviconView : Theme -> String -> Element Msg
faviconView theme faviconUrl =
    let
        bgColor =
            case theme of
                Dark ->
                    rgb255 203 213 225

                Light ->
                    rgb255 255 255 255
    in
    if faviconUrl /= "" then
        el
            [ width (px 20)
            , height (px 20)
            , Border.rounded 4
            , Background.color bgColor
            , Element.padding 2
            ]
            (image [ width fill, height fill ]
                { src = faviconUrl, description = "Feed favicon" }
            )

    else
        el
            [ width (px 20)
            , height (px 20)
            , Background.color bgColor
            , Border.rounded 4
            , Element.padding 2
            ]
            Element.none


feedItem : Time.Posix -> Theme -> Set String -> FeedItem -> Element Msg
feedItem now theme insertedIds item =
    let
        txtColor =
            textColor theme

        mutedTxt =
            Theme.mutedColor theme
    in
    let
        isInserted = Set.member item.link insertedIds
        wrapperAttrs =
            [ width fill
            , spacing 8
            , htmlAttribute (Html.Attributes.style "min-width" "0")
            , htmlAttribute (Html.Attributes.class "timeline-inserted-wrapper")
            ]
            ++ (if isInserted then [ htmlAttribute (Html.Attributes.class "timeline-inserted") ] else [])
    in
    row
        ([ width fill ] ++ wrapperAttrs)
        [ el
            [ width (px 6)
            , height (px 6)
            , Background.color (rgb255 255 165 0)
            , Border.rounded 3
            , Element.alignTop
            , paddingXY 0 6
            ]
            Element.none
        , paragraph
            [ Element.width fill
            , Ty.size13
            , Font.color txtColor
            , htmlAttribute (Html.Attributes.style "word-break" "break-word")
            , htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "line-height" "1.3")
            ]
            [ link
                [ Font.color txtColor
                , htmlAttribute (Html.Attributes.style "text-decoration" "none")
                ]
                { url = item.link, label = text item.title }
            ]
        , el
            [ Ty.small
            , Font.color mutedTxt
            , Element.alignTop
            , paddingXY 0 2
            ]
            (text (relativeTime now item.pubDate))
        ]


relativeTime : Time.Posix -> Maybe Time.Posix -> String
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
                let
                    month =
                        Time.toMonth Time.utc pubDate |> monthToString

                    day =
                        Time.toDay Time.utc pubDate |> String.fromInt
                in
                month ++ " " ++ day


monthToString : Time.Month -> String
monthToString month =
    case month of
        Time.Jan ->
            "Jan"

        Time.Feb ->
            "Feb"

        Time.Mar ->
            "Mar"

        Time.Apr ->
            "Apr"

        Time.May ->
            "May"

        Time.Jun ->
            "Jun"

        Time.Jul ->
            "Jul"

        Time.Aug ->
            "Aug"

        Time.Sep ->
            "Sep"

        Time.Oct ->
            "Oct"

        Time.Nov ->
            "Nov"

        Time.Dec ->
            "Dec"


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
