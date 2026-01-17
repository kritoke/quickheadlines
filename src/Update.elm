module Update exposing (update)

import Api exposing (..)
import Browser
import Browser.Navigation as Nav
import Ports exposing (..)
import Time exposing (Zone)
import Types exposing (..)
import Url exposing (Url)



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
            ( { newModel | page = page }, Cmd.none )

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
        |> Maybe.withDefault ""



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
                Ok feeds ->
                    ( { model | page = FeedsPage { feedsModel | feeds = feeds, loading = False, error = Nothing } }
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
                Ok items ->
                    let
                        newModel =
                            TimelinePage
                                { timelineModel
                                    | items = timelineModel.items ++ items
                                    , loading = False
                                    , currentOffset = timelineModel.currentOffset + List.length items
                                    , hasMore = not (List.isEmpty items)
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

        Http.BadStatus status _ ->
            "Server error: " ++ String.fromInt status

        Http.BadBody message ->
            "Invalid response: " ++ message
