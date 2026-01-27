module Pages.Home_ exposing (Model, Msg(..), init, page, subscriptions, update, view)

import Components.FeedBody as FeedBody
import Components.FeedBox as FeedBox
import Components.Header as Header
import Components.TabBar as TabBar
import Decoders exposing (feedsPageDecoder)
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes
import Http
import Page exposing (Page)
import Shared exposing (Shared)
import Theme exposing (getThemeColors)
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
    let
        paddingValue =
            responsivePadding shared.windowWidth
    in
    { title = "QuickHeadlines"
    , body =
        [ Html.div
            [ Html.Attributes.style "padding" (String.fromInt paddingValue ++ "px")
            , Html.Attributes.style "min-height" "100vh"
            , Html.Attributes.style "display" "flex"
            , Html.Attributes.style "flex-direction" "column"
            ]
            [ Html.div
                [ Html.Attributes.style "display" "flex"
                , Html.Attributes.style "flex-direction" "column"
                , Html.Attributes.style "height" "100%"
                , Html.Attributes.style "width" "100%"
                , Html.Attributes.style "gap" "1.25rem"
                ]
                [ Header.view shared.theme shared.lastUpdated shared.timeZone ToggleThemeRequested
                , TabBar.view shared.theme model.tabs model.activeTab SwitchTab
                , if model.loading then
                    loadingIndicator

                  else if model.error /= Nothing then
                    errorView (Maybe.withDefault "" model.error)

                  else
                    feedGrid shared.windowWidth shared.theme model.activeTab model.feeds
                ]
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


loadingIndicator : Html Msg
loadingIndicator =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "justify-content" "center"
        , Html.Attributes.style "align-items" "center"
        , Html.Attributes.style "padding" "2.5rem"
        ]
        [ Html.text "Loading..."
        ]


errorView : String -> Html Msg
errorView errorMessage =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "justify-content" "center"
        , Html.Attributes.style "align-items" "center"
        , Html.Attributes.style "padding" "1.25rem"
        , Html.Attributes.style "border-radius" "0.5rem"
        , Html.Attributes.style "border" "1px solid #dc2626"
        , Html.Attributes.style "background-color" "#fef2f2"
        , Html.Attributes.style "color" "#7f1d1d"
        ]
        [ Html.text ("Error: " ++ errorMessage)
        ]


feedGrid : Int -> Theme -> String -> List Feed -> Html Msg
feedGrid windowWidth theme activeTab feeds =
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
                "1.5rem"

            else if windowWidth >= 768 then
                "1.25rem"

            else
                "1rem"

        -- Use first tab if activeTab is empty, show all feeds for "all" tab
        effectiveTab =
            if activeTab == "" then
                ""
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
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "flex-direction" "column"
        , Html.Attributes.style "width" "100%"
        , Html.Attributes.style "gap" gapValue
        ]
        (List.map
            (\feedRow ->
                Html.div
                    [ Html.Attributes.style "display" "flex"
                    , Html.Attributes.style "flex-direction" "row"
                    , Html.Attributes.style "width" "100%"
                    , Html.Attributes.style "gap" gapValue
                    ]
                    (List.map
                        (\feed ->
                            FeedBox.view windowWidth (Time.millisToPosix 0) theme feed
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
