module Pages.Home_ exposing (Model, Msg(..), init, page, subscriptions, update, view)

import Components.FeedBody as FeedBody
import Components.FeedBox as FeedBox
import Components.Header as Header
import Components.TabBar as TabBar
import Decoders exposing (feedsPageDecoder)
import Effect exposing (Effect)
import Element exposing (Element, alignRight, alpha, centerX, centerY, clip, column, el, fill, fillPortion, height, inFront, link, maximum, minimum, mouseOver, padding, paddingXY, pointer, px, rgb255, row, scrollbarY, shrink, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Html
import Http
import Page exposing (Page)
import Shared exposing (Shared)
import Theme exposing (ThemeColors, getThemeColors)
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
    ( { activeTab = "all"
      , tabs = []
      , feeds = []
      , loading = True
      , error = Nothing
      }
    , Effect.batch
        [ Effect.sendCmd (fetchFeeds "all")
        ]
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
            , Effect.none
            )

        GotFeeds (Err error) ->
            ( { model
                | loading = False
                , error = Just (httpErrorToString error)
              }
            , Effect.none
            )

        SwitchTab tabName ->
            ( { model | activeTab = tabName, loading = True }
            , Effect.sendCmd (fetchFeeds tabName)
            )

        LoadMore url count ->
            ( model
            , Effect.sendCmd (fetchMoreItems url count)
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
            , Effect.none
            )

        GotMoreItems _ (Err error) ->
            ( { model | error = Just (httpErrorToString error) }
            , Effect.none
            )

        ToggleThemeRequested ->
            ( model
            , Effect.none
            )


view : Shared -> Model -> View Msg
view shared model =
    { title = "QuickHeadlines"
    , body =
        [ Element.layout
            [ width fill
            , height fill
            , padding (responsivePadding shared.windowWidth)
            , spacing 20
            , Background.color (getThemeColors shared.theme).background
            , Font.color (getThemeColors shared.theme).text
            ]
            (column
                [ width fill
                , height fill
                ]
                [ Header.view shared.theme shared.lastUpdated shared.timeZone ToggleThemeRequested
                , TabBar.view shared.theme model.tabs model.activeTab SwitchTab
                , if model.loading then
                    loadingIndicator (getThemeColors shared.theme)

                  else if model.error /= Nothing then
                    errorView (getThemeColors shared.theme) (Maybe.withDefault "" model.error)

                  else
                    feedGrid shared.windowWidth shared.now shared.theme model.tabs model.activeTab model.feeds
                ]
            )
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


loadingIndicator : ThemeColors -> Element msg
loadingIndicator colors =
    el
        [ centerX
        , padding 40
        ]
        (text "Loading...")


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
