port module Main exposing ( main )

{-|
@docs main
-}


import ApiRoute
import BackendTask
import Browser.Navigation
import Bytes
import Bytes.Decode
import Bytes.Encode
import Dict
import Effect
import ErrorPage
import FatalError
import Form
import Head
import Html
import Http
import Json.Decode
import Json.Encode
import Pages.ConcurrentSubmission
import Pages.Fetcher
import Pages.Flags
import Pages.Internal.NotFoundReason
import Pages.Internal.Platform.Cli
import Pages.Internal.ResponseSketch
import Pages.Internal.RoutePattern
import Pages.Navigation
import Pages.PageUrl
import PagesMsg
import Route
import Route.Index
import Route.Timeline
import Route.Clusters
import Server.Request
import Server.Response
import Shared
import SharedTemplate
import Site
import SiteConfig
import Url
import UrlPath
import View


type alias Model =
    { global : Shared.Model
    , page : PageModel
    , current :
        Maybe { path :
            { path : UrlPath.UrlPath
            , query : Maybe String
            , fragment : Maybe String
            }
        , metadata : Maybe Route.Route
        , pageUrl : Maybe Pages.PageUrl.PageUrl
        }
    }


type PageModel
    = ModelIndex Pages.Home.Index.Model
    | ModelTimeline Pages.Timeline.Index.Model
    | ModelClusters Pages.Clusters.Index.Model
    | NotFound


type Msg
    = MsgIndex Pages.Home.Index.Msg
    | MsgGlobal Shared.Msg
    | MsgTimeline Pages.Timeline.Index.Msg
    | MsgClusters Pages.Clusters.Index.Msg
    | OnPageChange
        { protocol : Url.Protocol
        , host : String
        , port_ : Maybe Int
        , path : UrlPath.UrlPath
        , query : Maybe String
        , fragment : Maybe String
        , metadata : Maybe Route.Route
        }
    | MsgErrorPage____ ErrorPage.Msg


type PageData
    = DataIndex Pages.Home.Index.Data
    | DataTimeline Pages.Timeline.Index.Data
    | DataClusters Pages.Clusters.Index.Data
    | Data404NotFoundPage____
    | DataErrorPage____ ErrorPage.ErrorPage


type ActionData
    = ActionDataHome Pages.Home.Index.ActionData
    | ActionDataTimeline Pages.Timeline.Index.ActionData
    | ActionDataClusters Pages.Clusters.Index.ActionData


main : Pages.Internal.Platform.Cli.Program (Maybe Route.Route)
main =
    Pages.Internal.Platform.Cli.cliApplication
        { init = init Nothing
        , update = update
        , subscriptions = subscriptions
        , sharedData = Shared.template.data
        , onPageChange = Just onPageChange
        }


init :
    Maybe Route.Route
    -> Shared.Model
    -> ( Model, Effect.Effect Msg )
init maybeRoute sharedModel =
    let
        initialPage : PageModel
        initialPage =
            case maybeRoute of
                Nothing ->
                    ModelIndex Pages.Home.Index.init

                Just Route.Index ->
                    ModelIndex Pages.Home.Index.init

                Just Route.Timeline ->
                    ModelTimeline Pages.Timeline.Index.init

                Just Route.Clusters ->
                    ModelClusters Pages.Clusters.Index.init

                _ ->
                    NotFound
    in
    ( { global = sharedModel
        , page = initialPage
        , current = Nothing
        , metadata = maybeRoute
        , pageUrl = Nothing
        }
    , Effect.none
    )


update : Msg -> Model -> ( Model, Effect.Effect Msg )
update msg model =
    case msg of
        MsgIndex indexMsg ->
            let
                ( newPageModel, pageEffects ) =
                    Pages.Home.Index.update indexMsg (case model.page of
                        ModelIndex pageModel ->
                            Pages.Home.Index.update indexMsg pageModel

                        _ ->
                            ( model.page, Effect.none )
                    )
            in
            ( { model | page = ModelIndex newPageModel }
            , Effect.map (\m -> m |> MsgIndex) pageEffects
            )

        MsgTimeline timelineMsg ->
            let
                ( newPageModel, pageEffects ) =
                    Pages.Timeline.Index.update timelineMsg (case model.page of
                        ModelTimeline pageModel ->
                            Pages.Timeline.Index.update timelineMsg pageModel

                        _ ->
                            ( model.page, Effect.none )
                    )
            in
            ( { model | page = ModelTimeline newPageModel }
            , Effect.map (\m -> m |> MsgTimeline) pageEffects
            )

        MsgClusters clustersMsg ->
            let
                ( newPageModel, pageEffects ) =
                    Pages.Clusters.Index.update clustersMsg (case model.page of
                        ModelClusters pageModel ->
                            Pages.Clusters.Index.update clustersMsg pageModel

                        _ ->
                            ( model.page, Effect.none )
                    )
            in
            ( { model | page = ModelClusters newPageModel }
            , Effect.map (\m -> m |> MsgClusters) pageEffects
            )

        MsgGlobal globalMsg ->
            let
                newShared =
                    Shared.update globalMsg model.global
            in
            ( { model | global = newShared }
            , Effect.map (\m -> m |> MsgGlobal) Effect.none
            )

        OnPageChange newPageState ->
            let
                newPage =
                    case newPageState.metadata of
                        Just Route.Index ->
                            let
                                ( pageModel, _ ) =
                                    Pages.Home.Index.init newPageState.path
                            in
                            ModelIndex pageModel

                        Just Route.Timeline ->
                            let
                                ( pageModel, _ ) =
                                    Pages.Timeline.Index.init newPageState.path
                            in
                            ModelTimeline pageModel

                        Just Route.Clusters ->
                            let
                                ( pageModel, _ ) =
                                    Pages.Clusters.Index.init newPageState.path
                            in
                            ModelClusters pageModel

                        _ ->
                            NotFound
            in
            ( { model
                | page = newPage
                , current = newPageState
                , metadata = newPageState.metadata
                }
            , Effect.none
            )

        MsgErrorPage____ errorMsg ->
            ( { model | page = ModelErrorPage____ ErrorPage.init errorMsg }
            , Effect.none
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- Update time every second for relative time display
          Time.every 1000 GotTime
        , -- Listen for window resize events
          Browser.Events.onResize (\w h -> MsgGlobal (Shared.WindowResized w h))
        , -- Listen for tab switch from JavaScript
          switchTab SwitchTab
        , -- Listen for OS theme changes from JavaScript
          envThemeChanged (\isDark -> MsgGlobal (Shared.SetSystemTheme isDark))
        ]


view : Model -> Browser.Document Msg
view model =
    let
        shared =
            model.global

        title =
            case model.page of
                ModelIndex _ ->
                    "QuickHeadlines"

                ModelTimeline _ ->
                    "Timeline"

                ModelClusters _ ->
                    "Clusters"

                NotFound ->
                    "Not Found"

        body =
            case model.page of
                ModelIndex pageModel ->
                    Pages.Home.Index.view shared pageModel

                ModelTimeline pageModel ->
                    Pages.Timeline.Index.view shared pageModel

                ModelClusters pageModel ->
                    Pages.Clusters.Index.view shared pageModel

                NotFound ->
                    [ Html.text "Page not found" ]
    in
    Browser.Document title
        [ Html.text body ]
    }


type Route
    = Route.Index Index
    | Route.Timeline Timeline
    | Route.Clusters Clusters


switchTab : String -> Msg
switchTab tab =
    MsgGlobal (Shared.SwitchTab tab)


onPageChange :
    { path :
        { path : UrlPath.UrlPath
        , query : Maybe String
        , fragment : Maybe String
        }
    , metadata : Maybe Route.Route
    -> Maybe ( ModelIndex.Model, Effect.Effect Route.Index.Msg )
onPageChange newPageState maybeMetadata =
    case maybeMetadata of
        Just (Route.Index) ->
            Just
                ( Pages.Home.Index.init newPageState.path
                , Effect.none
                )

        _ ->
            Nothing


GotTime : Time.Posix -> Msg
GotTime posix =
    MsgGlobal (Shared.SetTime posix)
