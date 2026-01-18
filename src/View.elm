module View exposing (view)

import Components.FeedBody as FeedBody
import Components.FeedBox as FeedBox
import Components.FeedHeader as FeedHeader
import Components.Header as Header
import Components.TabBar as TabBar
import Components.Timeline as Timeline
import Element exposing (Element, alignRight, alpha, centerX, centerY, clip, column, el, fill, fillPortion, height, inFront, link, maximum, minimum, mouseOver, padding, paddingXY, pointer, px, rgb255, row, scrollbarY, shrink, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Theme exposing (ThemeColors, getThemeColors)
import Time exposing (Posix, Zone)
import Types exposing (..)



-- Main view function that routes to appropriate page view


view : Model -> Element Msg
view model =
    let
        colors =
            getThemeColors model.theme
    in
    column
        [ width fill
        , height fill
        , Background.color colors.background
        , Font.color colors.text
        ]
        [ case model.page of
            FeedsPage feedsModel ->
                viewFeedsPage model feedsModel

            TimelinePage timelineModel ->
                viewTimelinePage model timelineModel

            NotFound ->
                viewNotFound
        ]



-- View for main feeds page with tabs and feed grid


viewFeedsPage : Model -> FeedsModel -> Element Msg
viewFeedsPage model feedsModel =
    let
        colors =
            getThemeColors model.theme
    in
    column
        [ width fill
        , padding (responsivePadding model.windowWidth)
        , spacing 20
        ]
        [ Header.view model.theme model.lastUpdated model.timeZone ToggleTheme
        , TabBar.view model.theme feedsModel.tabs feedsModel.activeTab (\tabName -> FeedsMsg (SwitchTab tabName))
        , if feedsModel.loading then
            loadingIndicator colors

          else if feedsModel.error /= Nothing then
            errorView colors (Maybe.withDefault "" feedsModel.error)

          else
            feedGrid model.windowWidth model.now model.theme feedsModel.tabs feedsModel.activeTab feedsModel.feeds
        ]



-- View for timeline page with infinite scroll


viewTimelinePage : Model -> TimelineModel -> Element Msg
viewTimelinePage model timelineModel =
    let
        colors =
            getThemeColors model.theme
    in
    column
        [ width fill
        , padding (responsivePadding model.windowWidth)
        , spacing 20
        ]
        [ Header.view model.theme model.lastUpdated model.timeZone ToggleTheme
        , if timelineModel.loading && List.isEmpty timelineModel.items then
            loadingIndicator colors

          else
            Timeline.view model.windowWidth model.theme model.timeZone model.now timelineModel
        ]



-- View for 404/not found pages


viewNotFound : Element Msg
viewNotFound =
    el
        [ centerX
        , centerY
        , padding 40
        , Font.size 24
        , Font.color (rgb255 100 116 139)
        ]
        (text "Page not found")



-- Loading spinner component


loadingIndicator : ThemeColors -> Element msg
loadingIndicator colors =
    el
        [ centerX
        , padding 40
        ]
        (text "Loading...")



-- Error message display


errorView : ThemeColors -> String -> Element msg
errorView colors errorMessage =
    el
        [ centerX
        , padding 20
        , Background.color (rgb255 254 226 226)
        , Border.color (rgb255 220 38 38)
        , Border.width 1
        , Border.rounded 8
        , Font.color (rgb255 127 29 29)
        ]
        (text ("Error: " ++ errorMessage))



-- Responsive feed grid layout (maps to CSS: grid-cols-1 md:grid-cols-2 lg:grid-cols-3)


feedGrid : Int -> Posix -> Theme -> List Tab -> String -> List Feed -> Element Msg
feedGrid windowWidth now theme tabs activeTab feeds =
    let
        colors =
            getThemeColors theme

        ( columnCount, gap ) =
            if windowWidth >= 1024 then
                ( 3, 24 )

            else if windowWidth >= 768 then
                ( 2, 20 )

            else
                ( 1, 16 )

        -- Use first tab if activeTab is empty, show all feeds for "all" tab
        effectiveTab =
            if activeTab == "" then
                tabs
                    |> List.head
                    |> Maybe.map .name
                    |> Maybe.withDefault ""

            else if activeTab == "all" then
                ""

            else
                activeTab

        -- Filter feeds by effectiveTab
        filteredFeeds =
            if effectiveTab == "" then
                feeds

            else
                List.filter (\feed -> feed.tab == effectiveTab) feeds

        chunkedFeeds =
            chunkList columnCount filteredFeeds
    in
    column
        [ width fill
        , spacing gap
        ]
        (List.map
            (\feedRow ->
                row
                    [ width fill
                    , spacing gap
                    ]
                    (List.map
                        (\feed ->
                            FeedBox.view windowWidth now theme feed
                        )
                        feedRow
                    )
            )
            chunkedFeeds
        )



-- Chunk list into sublists of given size


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



-- Split list at given index


splitAt : Int -> List a -> ( List a, List a )
splitAt n list =
    ( List.take n list, List.drop n list )



-- Responsive padding helper (maps to CSS: px-4 md:px-12 lg:px-24)


responsivePadding : Int -> Int
responsivePadding windowWidth =
    if windowWidth >= 1024 then
        96

    else if windowWidth >= 768 then
        48

    else
        16
