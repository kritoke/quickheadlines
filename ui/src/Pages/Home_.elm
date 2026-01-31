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
import Time


type alias Model =
    { feeds : List Feed
    , tabs : List String
    , activeTab : String
    , loading : Bool
    , error : Maybe String
    }


init : Shared.Model -> ( Model, Cmd Msg )
init shared =
    ( { feeds = []
      , tabs = []
      , activeTab = "all"
      , loading = True
      , error = Nothing
      }
    , fetchFeeds "all" GotFeeds
    )


type Msg
    = GotFeeds (Result Http.Error Api.FeedsResponse)
    | SwitchTab String


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


view : Shared.Model -> Model -> Element Msg
view shared model =
     let
         theme =
             shared.theme

         colors =
             themeToColors theme

         bg =
             surfaceColor theme

         isMobile =
             shared.windowWidth < 768

         paddingValue =
             if isMobile then
                 16

             else
                 96
     in
     column
        [ width fill
        , height fill
        , spacing 20
        , padding paddingValue
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

            border =
                Theme.borderColor theme
        in
        wrappedRow
            [ width fill
            , spacing 8
            , paddingEach { top = 0, right = 0, bottom = 16, left = 0 }
            , Border.widthEach { top = 0, right = 0, bottom = 1, left = 0 }
            , Border.color border
            ]
            (allTab shared :: List.map (tabButton shared model.activeTab) model.tabs)


allTab : Shared.Model -> Element Msg
allTab shared =
    let
        theme =
            shared.theme

        colors =
            themeToColors theme
    in
    el
        [ paddingXY 12 6
        , Border.rounded 6
        , Font.size 13
        , Font.medium
        , Font.color tabActiveText
        , Background.color (tabActiveBg theme)
        ]
        (text "All")


tabButton : Shared.Model -> String -> String -> Element Msg
tabButton shared activeTab tab =
    let
        theme =
            shared.theme

        isActive =
            tab == activeTab

        bg =
            if isActive then
                tabActiveBg theme

            else
                tabHoverBg theme

        txtColor =
            if isActive then
                tabActiveText

            else
                tabInactiveText theme
    in
    Input.button
        [ paddingXY 12 6
        , Border.rounded 6
        , Font.size 13
        , Font.medium
        , Font.color txtColor
        , Background.color bg
        ]
        { onPress = Just (SwitchTab tab)
        , label = text tab
        }


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
            , Font.size 16
            , Font.color muted
            ]
            (text "Loading...")

    else if model.error /= Nothing then
        el
            [ centerX
            , centerY
            , Font.size 16
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

        columnCount =
            if shared.windowWidth >= 1024 then
                3

            else if shared.windowWidth >= 768 then
                2

            else
                1

        gapValue =
            if shared.windowWidth >= 1024 then
                24

            else if shared.windowWidth >= 768 then
                20

            else
                16
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
                        (List.map (feedCard shared.now theme shared.windowWidth) feedRow)
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


feedCard : Time.Posix -> Theme -> Int -> Feed -> Element Msg
feedCard now theme windowWidth feed =
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
            if windowWidth >= 1024 then
                [ htmlAttribute (Html.Attributes.style "max-height" "280px")
                , htmlAttribute (Html.Attributes.style "overflow-y" "auto")
                , htmlAttribute (Html.Attributes.style "scrollbar-width" "thin")
                , htmlAttribute (Html.Attributes.style "scrollbar-color" "transparent transparent")
                , htmlAttribute (Html.Attributes.class "auto-hide-scroll")
                ]
            else
                []
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
            (List.map (feedItem now theme) (List.take 15 (sortFeedItems feed.items)))
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
                    "" -> Html.Attributes.attribute "style" "color: var(--header-text-color)"
                    _ -> Html.Attributes.style "color" headerTextColor)
                , Font.underline
                , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
                ]
                { url = feed.siteLink, label = text feed.title }
            , if feed.displayLink /= "" then
                el
                    [ htmlAttribute (Html.Attributes.attribute "data-display-link" "true")
                    , Font.size 12
                    , (case headerTextColor of
                        "" -> Html.Attributes.attribute "style" "color: var(--header-text-color)"
                        _ -> Html.Attributes.style "color" headerTextColor)
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


feedItem : Time.Posix -> Theme -> FeedItem -> Element Msg
feedItem now theme item =
    let
        txtColor =
            textColor theme

        mutedTxt =
            Theme.mutedColor theme
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
            , Element.alignTop
            , paddingXY 0 6
            ]
            Element.none
        , paragraph
            [ Element.width fill
            , Font.size 11
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
            [ Font.size 11
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
