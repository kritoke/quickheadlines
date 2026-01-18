port module Main exposing (..)

import Api exposing (getFeedMore, getFeeds, getTimelineItems, getVersion)
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element exposing (layout, rgb255)
import Element.Background as Background
import Element.Font as Font
import Html
import Http
import Json.Decode exposing (Value)
import Set exposing (Set)
import Task
import Time exposing (Posix, Zone)
import Types exposing (FeedsModel, FeedsMsg(..), Model, Msg(..), Page(..), Theme(..), TimelineModel, TimelineMsg(..))
import Url exposing (Url)
import View exposing (view)



-- PORTS
-- Send theme to JavaScript


port setTheme : String -> Cmd msg



-- Receive theme from JavaScript


port themeChanged : (String -> msg) -> Sub msg



-- Initialize theme from cookie/storage


port initTheme : () -> Cmd msg



-- Send scroll position to JavaScript


port updateScrollShadow : { elementId : String, isAtBottom : Bool } -> Cmd msg



-- Receive scroll events from JavaScript


port scrollEvent : ({ elementId : String, scrollTop : Int, scrollHeight : Int, clientHeight : Int } -> msg) -> Sub msg



-- Request to observe element


port observeElement : String -> Cmd msg



-- Receive intersection events from JavaScript


port elementIntersected : ({ elementId : String, isIntersecting : Bool } -> msg) -> Sub msg



-- Request color extraction from image


port extractColor : { imageUrl : String, feedUrl : String } -> Cmd msg



-- Receive extracted color from JavaScript


port colorExtracted : ({ feedUrl : String, backgroundColor : String, textColor : String } -> msg) -> Sub msg



-- Window resize events


port windowResized : ({ width : Int, height : Int } -> msg) -> Sub msg



-- Main entry point


main : Program Value Model Msg
main =
    Browser.application
        { init = init
        , view = viewDocument
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- Initialize the application


init : Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        theme =
            Light

        initialPage =
            extractPageFromUrl url
                |> Maybe.withDefault (FeedsPage (initialFeedsModel "Tech"))

        initialModel =
            { key = key
            , url = url
            , page = initialPage
            , theme = theme
            , windowWidth = 1280
            , windowHeight = 720
            , lastUpdated = Nothing
            , now = Time.millisToPosix 0
            , timeZone = Time.utc
            }
    in
    ( initialModel
    , Cmd.batch
        [ case initialPage of
            TimelinePage _ ->
                getTimelineItems 30 0

            _ ->
                getFeeds (extractTabFromUrl url)
        , getVersion
        , Task.perform Tick Time.now
        ]
    )



-- View document wrapper


viewDocument : Model -> Browser.Document Msg
viewDocument model =
    let
        bgColor =
            if model.theme == Light then
                rgb255 249 250 251

            else
                rgb255 17 24 39

        textColor =
            if model.theme == Light then
                rgb255 30 41 59

            else
                rgb255 226 232 240
    in
    { title = "QuickHeadlines"
    , body =
        [ layout
            [ Background.color bgColor
            , Font.color textColor
            ]
            (view model)
        ]
    }



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 60000 Tick
        , Browser.Events.onResize WindowResized
        ]



-- Main update function


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChanged url ->
            handleUrlChanged url model

        LinkClicked urlRequest ->
            handleLinkClicked urlRequest model

        WindowResized width height ->
            ( { model | windowWidth = width, windowHeight = height }, Cmd.none )

        TimeZoneChanged zone ->
            ( { model | timeZone = zone }, Cmd.none )

        ToggleTheme ->
            let
                newTheme =
                    case model.theme of
                        Light ->
                            Dark

                        Dark ->
                            Light
            in
            ( { model | theme = newTheme }
            , setTheme (themeToString newTheme)
            )

        GotLastUpdated result ->
            handleGotLastUpdated result model

        CheckForUpdates ->
            ( model, getVersion )

        Tick time ->
            ( { model | now = time }, Cmd.none )

        FeedsMsg feedsMsg ->
            updateFeeds feedsMsg model

        TimelineMsg timelineMsg ->
            updateTimeline timelineMsg model



-- Handle URL changes


handleUrlChanged : Url -> Model -> ( Model, Cmd Msg )
handleUrlChanged url model =
    let
        newModel =
            { model | url = url }
    in
    case extractPageFromUrl url of
        Just page ->
            let
                cmd =
                    case page of
                        TimelinePage _ ->
                            getTimelineItems 30 0

                        _ ->
                            Cmd.none
            in
            ( { newModel | page = page }, cmd )

        Nothing ->
            ( { newModel | page = NotFound }, Cmd.none )



-- Extract page from URL


extractPageFromUrl : Url -> Maybe Page
extractPageFromUrl url =
    if url.path == "/" then
        Just (FeedsPage (initialFeedsModel (extractTabFromUrl url)))

    else if url.path == "/timeline" then
        Just (TimelinePage initialTimelineModel)

    else
        Nothing



-- Extract tab from URL query parameters


extractTabFromUrl : Url -> String
extractTabFromUrl url =
    url.query
        |> Maybe.andThen (extractQueryParam "tab")
        |> Maybe.withDefault "Tech"



-- Extract query parameter from URL


extractQueryParam : String -> String -> Maybe String
extractQueryParam param queryString =
    queryString
        |> String.split "&"
        |> List.map (String.split "=")
        |> List.filterMap
            (\parts ->
                case parts of
                    [ key, value ] ->
                        if key == param then
                            Just value

                        else
                            Nothing

                    _ ->
                        Nothing
            )
        |> List.head



-- Handle link clicks


handleLinkClicked : Browser.UrlRequest -> Model -> ( Model, Cmd Msg )
handleLinkClicked urlRequest model =
    case urlRequest of
        Browser.Internal url ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        Browser.External href ->
            ( model, Nav.load href )



-- Handle version response


handleGotLastUpdated : Result Http.Error Posix -> Model -> ( Model, Cmd Msg )
handleGotLastUpdated result model =
    case result of
        Ok time ->
            ( { model | lastUpdated = Just time }, Cmd.none )

        Err _ ->
            ( model, Cmd.none )



-- Update feeds page


updateFeeds : FeedsMsg -> Model -> ( Model, Cmd Msg )
updateFeeds msg model =
    case model.page of
        FeedsPage feedsModel ->
            updateFeedsModel msg feedsModel model

        _ ->
            ( model, Cmd.none )



-- Update feeds model


updateFeedsModel : FeedsMsg -> FeedsModel -> Model -> ( Model, Cmd Msg )
updateFeedsModel msg feedsModel model =
    case msg of
        SwitchTab tab ->
            let
                newFeedsModel =
                    { feedsModel | activeTab = tab, loading = True, feeds = [] }
            in
            ( { model | page = FeedsPage newFeedsModel }
            , getFeeds tab
            )

        GotFeeds result ->
            case result of
                Ok response ->
                    ( { model | page = FeedsPage { feedsModel | tabs = response.tabs, activeTab = response.activeTab, feeds = response.feeds, loading = False, error = Nothing } }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | page = FeedsPage { feedsModel | loading = False, error = Just (errorToString error) } }
                    , Cmd.none
                    )

        LoadMore url offset ->
            ( model, getFeedMore url offset )

        GotMoreItems url result ->
            case result of
                Ok feed ->
                    let
                        newFeeds =
                            List.map
                                (\f ->
                                    if f.url == url then
                                        { f | items = f.items ++ feed.items, totalItemCount = feed.totalItemCount }

                                    else
                                        f
                                )
                                feedsModel.feeds
                    in
                    ( { model | page = FeedsPage { feedsModel | feeds = newFeeds } }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        UpdateAdaptiveColors ->
            ( model, Cmd.none )



-- Update timeline page


updateTimeline : TimelineMsg -> Model -> ( Model, Cmd Msg )
updateTimeline msg model =
    case model.page of
        TimelinePage timelineModel ->
            updateTimelineModel msg timelineModel model

        _ ->
            ( model, Cmd.none )



-- Update timeline model


updateTimelineModel : TimelineMsg -> TimelineModel -> Model -> ( Model, Cmd Msg )
updateTimelineModel msg timelineModel model =
    case msg of
        LoadMoreTimeline ->
            if timelineModel.hasMore && not timelineModel.loading then
                ( { model | page = TimelinePage { timelineModel | loading = True } }
                , getTimelineItems 30 timelineModel.currentOffset
                )

            else
                ( model, Cmd.none )

        GotTimelineItems result ->
            case result of
                Ok response ->
                    let
                        newItems =
                            response.items

                        newModel =
                            TimelinePage
                                { timelineModel
                                    | items = timelineModel.items ++ newItems
                                    , loading = False
                                    , currentOffset = timelineModel.currentOffset + List.length newItems
                                    , hasMore = response.hasMore
                                }
                    in
                    ( { model | page = newModel }, Cmd.none )

                Err _ ->
                    ( { model | page = TimelinePage { timelineModel | loading = False } }
                    , Cmd.none
                    )

        ExpandCluster clusterId ->
            ( { model | page = TimelinePage { timelineModel | expandedClusters = Set.insert clusterId timelineModel.expandedClusters } }
            , Cmd.none
            )

        CollapseCluster clusterId ->
            ( { model | page = TimelinePage { timelineModel | expandedClusters = Set.remove clusterId timelineModel.expandedClusters } }
            , Cmd.none
            )



-- Initial feeds model


initialFeedsModel : String -> FeedsModel
initialFeedsModel activeTab =
    { activeTab = activeTab
    , tabs = []
    , feeds = []
    , loading = True
    , error = Nothing
    }



-- Initial timeline model


initialTimelineModel : TimelineModel
initialTimelineModel =
    { items = []
    , loading = True
    , hasMore = True
    , currentOffset = 0
    , expandedClusters = Set.empty
    }



-- Convert theme to string for JavaScript


themeToString : Theme -> String
themeToString theme =
    case theme of
        Light ->
            "light"

        Dark ->
            "dark"



-- Error to string helper


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "Invalid URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Server error: " ++ String.fromInt status

        Http.BadBody message ->
            "Invalid response: " ++ message
