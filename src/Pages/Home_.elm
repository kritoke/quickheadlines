module Pages.Home_ exposing (Model, Msg(..), init, page, subscriptions, update, view)

import Components.FeedBox as FeedBox
import Components.Header as Header
import Components.TabBar as TabBar
import Decoders exposing (feedsPageDecoder)
import AppEffect exposing (Effect)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Http
import Page exposing (Page)
import Shared exposing (Shared)
import Task
import Theme exposing (errorBgColor, errorBorderColor, errorTextColor, surfaceColor, textColor)
import Time exposing (Posix, Zone)
import Types exposing (Feed, FeedItem, Tab, Theme(..))
import View exposing (View)


page : Shared -> Page Model Msg
page shared =
    Page.new
        { init = init shared
        , update = update shared
        , view = view shared
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    { activeTab : String
    , tabs : List Tab
    , feeds : List Feed
    , loading : Bool
    , error : Maybe String
    }


init : Shared -> () -> ( Model, Effect Msg )
init shared _ =
    let
        _ = Debug.log "Home.init" "starting"
    in
    ( { activeTab = "all"
      , tabs = []
      , feeds = []
      , loading = True
      , error = Nothing
      }
    , AppEffect.sendCmd (Http.get
        { url = "/api/feeds?tab=all"
        , expect = Http.expectJson GotFeeds feedsPageDecoder
        })
    )


type Msg
    = GotFeeds (Result Http.Error { tabs : List Tab, activeTab : String, feeds : List Feed })
    | SwitchTab String
    | LoadMore String Int
    | GotMoreItems String (Result Http.Error Feed)
    | ToggleThemeRequested


update : Shared -> Msg -> Model -> ( Model, Effect Msg )
update shared msg model =
    case msg of
        GotFeeds (Ok data) ->
            ( { model
                | tabs = data.tabs
                , activeTab = data.activeTab
                , feeds = data.feeds
                , loading = False
                , error = Nothing
              }
            , AppEffect.none
            )

        GotFeeds (Err error) ->
            ( { model
                | loading = False
                , error = Just (httpErrorToString error)
              }
            , AppEffect.none
            )

        SwitchTab tabName ->
            ( { model | activeTab = tabName, loading = True }
            , AppEffect.sendCmd (fetchFeeds tabName)
            )

        LoadMore url count ->
            ( model
            , AppEffect.sendCmd (fetchMoreItems url count)
            )

        GotMoreItems url (Ok feed) ->
            ( { model
                | feeds =
                    List.map
                        (\f ->
                            if f.url == url then
                                feed

                            else
                                f
                        )
                        model.feeds
              }
            , AppEffect.none
            )

        GotMoreItems _ (Err error) ->
            ( { model | error = Just (httpErrorToString error) }
            , AppEffect.none
            )

        ToggleThemeRequested ->
            ( model
            , AppEffect.sendMsg ToggleThemeRequested
            )


view : Shared -> Model -> View Msg
view shared model =
    let
        paddingValue =
            responsivePadding shared.windowWidth

        content =
            if model.loading then
                loadingIndicator shared.theme

            else if model.error /= Nothing then
                errorView shared.theme (Maybe.withDefault "" model.error)

            else
                feedGrid shared.windowWidth shared.theme model.activeTab model.feeds shared.now
    in
    { title = "QuickHeadlines"
    , body =
        column
            [ padding paddingValue
            , height fill
            , width fill
            , Background.color (Theme.surfaceColor shared.theme)
            ]
            [ column
                [ width fill
                , height fill
                , spacing 20
                ]
                [ Header.view shared.windowWidth shared.theme shared.lastUpdated shared.timeZone ToggleThemeRequested
                , TabBar.view shared.theme model.tabs model.activeTab SwitchTab
                , content
                ]
            ]
    }


fetchFeeds : String -> Cmd Msg
fetchFeeds tab =
    Http.get
        { url = "/api/feeds?tab=" ++ tab
        , expect = Http.expectJson GotFeeds feedsPageDecoder
        }


fetchMoreItems : String -> Int -> Cmd Msg
fetchMoreItems url count =
    Http.get
        { url = "/api/feed_more?url=" ++ url ++ "&limit=" ++ String.fromInt count ++ "&offset=0"
        , expect = Http.expectJson (GotMoreItems url) Decoders.feedDecoder
        }


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Server returned status: " ++ String.fromInt status

        Http.BadBody message ->
            "Invalid response: " ++ message


loadingIndicator : Theme -> Element msg
loadingIndicator theme =
    el
        [ centerX
        , centerY
        , padding 40
        , Font.size 16
        , Font.color (Theme.textColor theme)
        ]
        (text "Loading...")


errorView : Theme -> String -> Element msg
errorView theme errorMessage =
    row
        [ centerX
        , centerY
        , padding 20
        , Border.rounded 8
        , Border.width 1
        , Border.color (errorBorderColor theme)
        , Background.color (errorBgColor theme)
        , width fill
        ]
        [ el
            [ Font.color (errorTextColor theme)
            , centerX
            ]
            (text ("Error: " ++ errorMessage))
        ]


feedGrid : Int -> Theme -> String -> List Feed -> Posix -> Element Msg
feedGrid windowWidth theme activeTab feeds now =
    let
        columnCount =
            if windowWidth >= 1024 then
                3

            else if windowWidth >= 768 then
                2

            else
                1

        gapValue =
            if windowWidth >= 1024 then
                24

            else if windowWidth >= 768 then
                20

            else
                16

        effectiveTab =
            if activeTab == "" then
                ""

            else if activeTab == "all" then
                ""

            else
                activeTab

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
        , spacing gapValue
        ]
        (List.map
            (\feedRow ->
                row
                    [ width fill
                    , spacing gapValue
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


responsivePadding : Int -> Int
responsivePadding windowWidth =
    if windowWidth >= 1024 then
        96

    else if windowWidth >= 768 then
        48

    else
        16


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
