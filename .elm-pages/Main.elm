port module Main exposing ( main )

{-|
@docs main
-}


import Api
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
import Pages.Internal.Platform
import Pages.Internal.ResponseSketch
import Pages.Internal.RoutePattern
import Pages.Navigation
import Pages.PageUrl
import PagesMsg
import Route
import Route.Clusters
import Route.Index
import Route.Timeline
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
    = ModelClusters Route.Clusters.Model
    | ModelTimeline Route.Timeline.Model
    | ModelIndex Route.Index.Model
    | ModelErrorPage____ ErrorPage.Model
    | NotFound


type Msg
    = MsgClusters Route.Clusters.Msg
    | MsgTimeline Route.Timeline.Msg
    | MsgIndex Route.Index.Msg
    | MsgGlobal Shared.Msg
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
    = DataClusters Route.Clusters.Data
    | DataTimeline Route.Timeline.Data
    | DataIndex Route.Index.Data
    | Data404NotFoundPage____
    | DataErrorPage____ ErrorPage.ErrorPage


type ActionData
    = ActionDataClusters Route.Clusters.ActionData
    | ActionDataTimeline Route.Timeline.ActionData
    | ActionDataIndex Route.Index.ActionData


main :
    Platform.Program Pages.Internal.Platform.Flags (Pages.Internal.Platform.Model Model PageData ActionData Shared.Data) (Pages.Internal.Platform.Msg Msg PageData ActionData Shared.Data ErrorPage.ErrorPage)
main =
    Pages.Internal.Platform.application
        { init = init Nothing
        , update = update
        , subscriptions = subscriptions
        , sharedData = Shared.template.data
        , data = dataForRoute
        , action = action
        , onActionData = onActionData
        , view = view
        , handleRoute = handleRoute
        , getStaticRoutes = BackendTask.succeed []
        , urlToRoute = Route.urlToRoute
        , routeToPath =
            \route -> Maybe.withDefault [] (Maybe.map Route.routeToPath route)
        , site = Nothing
        , toJsPort = toJsPort
        , fromJsPort = fromJsPort Basics.identity
        , gotBatchSub = Sub.none
        , hotReloadData = hotReloadData Basics.identity
        , onPageChange = OnPageChange
        , apiRoutes = \htmlToString -> []
        , pathPatterns = routePatterns3
        , basePath = Route.baseUrlAsPath
        , sendPageData = sendPageData
        , byteEncodePageData = byteEncodePageData
        , byteDecodePageData = byteDecodePageData
        , encodeResponse = encodeResponse
        , encodeAction = encodeActionData
        , decodeResponse = decodeResponse
        , globalHeadTags = Nothing
        , cmdToEffect = Effect.fromCmd
        , perform = Effect.perform
        , errorStatusCode = ErrorPage.statusCode
        , notFoundPage = ErrorPage.notFound
        , internalError = ErrorPage.internalError
        , errorPageToData = DataErrorPage____
        , notFoundRoute = Nothing
        }


dataForRoute :
    Server.Request.Request
    -> Maybe Route.Route
    -> BackendTask.BackendTask FatalError.FatalError (Server.Response.Response PageData ErrorPage.ErrorPage)
dataForRoute requestPayload maybeRoute =
    case maybeRoute of
        Nothing ->
            BackendTask.succeed
                (Server.Response.mapError
                     Basics.never
                     (Server.Response.withStatusCode
                          404
                          (Server.Response.render Data404NotFoundPage____)
                     )
                )
    
        Just justRoute ->
            case justRoute of
                Route.Clusters ->
                    BackendTask.map
                        (Server.Response.map DataClusters)
                        (Route.Clusters.route.data requestPayload {})
            
                Route.Timeline ->
                    BackendTask.map
                        (Server.Response.map DataTimeline)
                        (Route.Timeline.route.data requestPayload {})
            
                Route.Index ->
                    BackendTask.map
                        (Server.Response.map DataIndex)
                        (Route.Index.route.data requestPayload {})


toTriple : a -> b -> c -> ( a, b, c )
toTriple a b c =
    ( a, b, c )


action :
    Server.Request.Request
    -> Maybe Route.Route
    -> BackendTask.BackendTask FatalError.FatalError (Server.Response.Response ActionData ErrorPage.ErrorPage)
action requestPayload maybeRoute =
    case maybeRoute of
        Nothing ->
            BackendTask.succeed (Server.Response.plainText "TODO")
    
        Just justRoute ->
            case justRoute of
                Route.Clusters ->
                    BackendTask.map
                        (Server.Response.map ActionDataClusters)
                        (Route.Clusters.route.action requestPayload {})
            
                Route.Timeline ->
                    BackendTask.map
                        (Server.Response.map ActionDataTimeline)
                        (Route.Timeline.route.action requestPayload {})
            
                Route.Index ->
                    BackendTask.map
                        (Server.Response.map ActionDataIndex)
                        (Route.Index.route.action requestPayload {})


fooFn :
    (a -> PageModel)
    -> (b -> Msg)
    -> Model
    -> ( a, Effect.Effect b, Maybe Shared.Msg )
    -> ( PageModel, Effect.Effect Msg, ( Shared.Model, Effect.Effect Shared.Msg ) )
fooFn wrapModel wrapMsg model triple =
    case triple of
        ( a, b, c ) ->
            ( wrapModel a
            , Effect.map wrapMsg b
            , case c of
                Nothing ->
                    ( model.global, Effect.none )
              
                Just sharedMsg ->
                    Shared.template.update sharedMsg model.global
            )


templateSubscriptions :
    Maybe Route.Route -> UrlPath.UrlPath -> Model -> Sub.Sub Msg
templateSubscriptions route path model =
    case route of
        Nothing ->
            Sub.none
    
        Just justRoute ->
            case justRoute of
                Route.Clusters ->
                    case model.page of
                        ModelClusters templateModel ->
                            Sub.map
                                MsgClusters
                                (Route.Clusters.route.subscriptions
                                     {}
                                     path
                                     templateModel
                                     model.global
                                )
                    
                        _ ->
                            Sub.none
            
                Route.Timeline ->
                    case model.page of
                        ModelTimeline templateModel ->
                            Sub.map
                                MsgTimeline
                                (Route.Timeline.route.subscriptions
                                     {}
                                     path
                                     templateModel
                                     model.global
                                )
                    
                        _ ->
                            Sub.none
            
                Route.Index ->
                    case model.page of
                        ModelIndex templateModel ->
                            Sub.map
                                MsgIndex
                                (Route.Index.route.subscriptions
                                     {}
                                     path
                                     templateModel
                                     model.global
                                )
                    
                        _ ->
                            Sub.none


onActionData : ActionData -> Maybe Msg
onActionData actionData =
    case actionData of
        ActionDataClusters thisActionData ->
            Maybe.map
                (\mapUnpack -> MsgClusters (mapUnpack thisActionData))
                Route.Clusters.route.onAction
    
        ActionDataTimeline thisActionData ->
            Maybe.map
                (\mapUnpack -> MsgTimeline (mapUnpack thisActionData))
                Route.Timeline.route.onAction
    
        ActionDataIndex thisActionData ->
            Maybe.map
                (\mapUnpack -> MsgIndex (mapUnpack thisActionData))
                Route.Index.route.onAction


byteEncodePageData : PageData -> Bytes.Encode.Encoder
byteEncodePageData pageData =
    case pageData of
        DataErrorPage____ thisPageData ->
            ErrorPage.w3_encode_ErrorPage thisPageData
    
        Data404NotFoundPage____ ->
            Bytes.Encode.unsignedInt8 0
    
        DataClusters thisPageData ->
            Route.Clusters.w3_encode_Data thisPageData
    
        DataTimeline thisPageData ->
            Route.Timeline.w3_encode_Data thisPageData
    
        DataIndex thisPageData ->
            Route.Index.w3_encode_Data thisPageData


byteDecodePageData : Maybe Route.Route -> Bytes.Decode.Decoder PageData
byteDecodePageData maybeRoute =
    case maybeRoute of
        Nothing ->
            Bytes.Decode.fail
    
        Just route ->
            case route of
                Route.Clusters ->
                    Bytes.Decode.map DataClusters Route.Clusters.w3_decode_Data
            
                Route.Timeline ->
                    Bytes.Decode.map DataTimeline Route.Timeline.w3_decode_Data
            
                Route.Index ->
                    Bytes.Decode.map DataIndex Route.Index.w3_decode_Data


apiPatterns : ApiRoute.ApiRoute ApiRoute.Response
apiPatterns =
    ApiRoute.single
        (ApiRoute.literal
             "api-patterns.json"
             (ApiRoute.succeed
                  (BackendTask.succeed
                       (Json.Encode.encode
                            0
                            (Json.Encode.list
                                 Basics.identity
                                 (List.map
                                      ApiRoute.toJson
                                      (Api.routes
                                           getStaticRoutes
                                           (\routesUnpack -> \unpack -> "")
                                      )
                                 )
                            )
                       )
                  )
             )
        )


init :
    Maybe Shared.Model
    -> Pages.Flags.Flags
    -> Shared.Data
    -> PageData
    -> Maybe ActionData
    -> Maybe { path :
        { path : UrlPath.UrlPath
        , query : Maybe String
        , fragment : Maybe String
        }
    , metadata : Maybe Route.Route
    , pageUrl : Maybe Pages.PageUrl.PageUrl
    }
    -> ( Model, Effect.Effect Msg )
init currentGlobalModel userFlags sharedData pageData actionData maybePagePath =
    let
        ( sharedModel, globalCmd ) =
            Maybe.withDefault
                (Shared.template.init userFlags maybePagePath)
                (Maybe.map
                     (\mapUnpack -> ( mapUnpack, Effect.none ))
                     currentGlobalModel
                )
        
        ( templateModel, templateCmd ) =
            case
                Maybe.map2
                    Tuple.pair
                    (Maybe.andThen .metadata maybePagePath)
                    (Maybe.map .path maybePagePath)
            of
                Nothing ->
                    initErrorPage pageData
            
                Just justRouteAndPath ->
                    case ( Tuple.first justRouteAndPath, pageData ) of
                        ( Route.Clusters, DataClusters thisPageData ) ->
                            Tuple.mapBoth
                                ModelClusters
                                (Effect.map MsgClusters)
                                (Route.Clusters.route.init
                                     sharedModel
                                     { data = thisPageData
                                     , sharedData = sharedData
                                     , action =
                                         Maybe.andThen
                                             (\andThenUnpack ->
                                                  case andThenUnpack of
                                                      ActionDataClusters thisActionData ->
                                                          Just thisActionData
                                                  
                                                      _ ->
                                                          Nothing
                                             )
                                             actionData
                                     , routeParams = {}
                                     , path =
                                         (Tuple.second justRouteAndPath).path
                                     , url =
                                         Maybe.andThen .pageUrl maybePagePath
                                     , submit =
                                         Pages.Fetcher.submit
                                             Route.Clusters.w3_decode_ActionData
                                     , navigation = Nothing
                                     , concurrentSubmissions = Dict.empty
                                     , pageFormState = Dict.empty
                                     }
                                )
                    
                        ( Route.Timeline, DataTimeline thisPageData ) ->
                            Tuple.mapBoth
                                ModelTimeline
                                (Effect.map MsgTimeline)
                                (Route.Timeline.route.init
                                     sharedModel
                                     { data = thisPageData
                                     , sharedData = sharedData
                                     , action =
                                         Maybe.andThen
                                             (\andThenUnpack ->
                                                  case andThenUnpack of
                                                      ActionDataTimeline thisActionData ->
                                                          Just thisActionData
                                                  
                                                      _ ->
                                                          Nothing
                                             )
                                             actionData
                                     , routeParams = {}
                                     , path =
                                         (Tuple.second justRouteAndPath).path
                                     , url =
                                         Maybe.andThen .pageUrl maybePagePath
                                     , submit =
                                         Pages.Fetcher.submit
                                             Route.Timeline.w3_decode_ActionData
                                     , navigation = Nothing
                                     , concurrentSubmissions = Dict.empty
                                     , pageFormState = Dict.empty
                                     }
                                )
                    
                        ( Route.Index, DataIndex thisPageData ) ->
                            Tuple.mapBoth
                                ModelIndex
                                (Effect.map MsgIndex)
                                (Route.Index.route.init
                                     sharedModel
                                     { data = thisPageData
                                     , sharedData = sharedData
                                     , action =
                                         Maybe.andThen
                                             (\andThenUnpack ->
                                                  case andThenUnpack of
                                                      ActionDataIndex thisActionData ->
                                                          Just thisActionData
                                                  
                                                      _ ->
                                                          Nothing
                                             )
                                             actionData
                                     , routeParams = {}
                                     , path =
                                         (Tuple.second justRouteAndPath).path
                                     , url =
                                         Maybe.andThen .pageUrl maybePagePath
                                     , submit =
                                         Pages.Fetcher.submit
                                             Route.Index.w3_decode_ActionData
                                     , navigation = Nothing
                                     , concurrentSubmissions = Dict.empty
                                     , pageFormState = Dict.empty
                                     }
                                )
                    
                        _ ->
                            initErrorPage pageData
    in
    ( { global = sharedModel, page = templateModel, current = maybePagePath }
    , Effect.batch [ templateCmd, Effect.map MsgGlobal globalCmd ]
    )


update :
    Form.Model
    -> Dict.Dict String (Pages.ConcurrentSubmission.ConcurrentSubmission ActionData)
    -> Maybe Pages.Navigation.Navigation
    -> Shared.Data
    -> PageData
    -> Maybe Browser.Navigation.Key
    -> Msg
    -> Model
    -> ( Model, Effect.Effect Msg )
update pageFormState concurrentSubmissions navigation sharedData pageData navigationKey msg model =
    case msg of
        MsgErrorPage____ msg_ ->
            let
                ( updatedPageModel, pageCmd ) =
                    case ( model.page, pageData ) of
                        ( ModelErrorPage____ pageModel, DataErrorPage____ thisPageData ) ->
                            Tuple.mapBoth
                                ModelErrorPage____
                                (Effect.map MsgErrorPage____)
                                (ErrorPage.update thisPageData msg_ pageModel)
                    
                        _ ->
                            ( model.page, Effect.none )
            in
            ( { model | page = updatedPageModel }, pageCmd )
    
        MsgGlobal msg_ ->
            let
                ( sharedModel, globalCmd ) =
                    Shared.template.update msg_ model.global
            in
            ( { model | global = sharedModel }, Effect.map MsgGlobal globalCmd )
    
        OnPageChange record ->
            let
                ( updatedModel, cmd ) =
                    init
                        (Just model.global)
                        Pages.Flags.PreRenderFlags
                        sharedData
                        pageData
                        Nothing
                        (Just
                             { path =
                                 { path = record.path
                                 , query = record.query
                                 , fragment = record.fragment
                                 }
                             , metadata = record.metadata
                             , pageUrl =
                                 Just
                                     { protocol = record.protocol
                                     , host = record.host
                                     , port_ = record.port_
                                     , path = record.path
                                     , query =
                                         Maybe.withDefault
                                             Dict.empty
                                             (Maybe.map
                                                  Pages.PageUrl.parseQueryParams
                                                  record.query
                                             )
                                     , fragment = record.fragment
                                     }
                             }
                        )
            in
            case Shared.template.onPageChange of
                Nothing ->
                    ( updatedModel, cmd )
            
                Just thingy ->
                    let
                        ( updatedGlobalModel, globalCmd ) =
                            Shared.template.update
                                (thingy
                                     { path = record.path
                                     , query = record.query
                                     , fragment = record.fragment
                                     }
                                )
                                model.global
                    in
                    ( { updatedModel | global = updatedGlobalModel }
                    , Effect.batch [ cmd, Effect.map MsgGlobal globalCmd ]
                    )
    
        MsgClusters msg_ ->
            case
                ( model.page
                , pageData
                , Maybe.map3
                    toTriple
                    (Maybe.andThen .metadata model.current)
                    (Maybe.andThen .pageUrl model.current)
                    (Maybe.map .path model.current)
                )
            of
                ( ModelClusters pageModel, DataClusters thisPageData, Just ( Route.Clusters, pageUrl, justPage ) ) ->
                    let
                        ( updatedPageModel, pageCmd, globalModelAndCmd ) =
                            fooFn
                                ModelClusters
                                MsgClusters
                                model
                                (Route.Clusters.route.update
                                     { data = thisPageData
                                     , sharedData = sharedData
                                     , action = Nothing
                                     , routeParams = {}
                                     , path = justPage.path
                                     , url = Just pageUrl
                                     , submit =
                                         \options ->
                                             Pages.Fetcher.submit
                                                 Route.Clusters.w3_decode_ActionData
                                                 options
                                     , navigation = navigation
                                     , concurrentSubmissions =
                                         Dict.map
                                             (\mapUnpack ->
                                                  Pages.ConcurrentSubmission.map
                                                      (\mapUnpack0 ->
                                                           case mapUnpack0 of
                                                               ActionDataClusters justActionData ->
                                                                   Just
                                                                       justActionData
                                                           
                                                               _ ->
                                                                   Nothing
                                                      )
                                             )
                                             concurrentSubmissions
                                     , pageFormState = pageFormState
                                     }
                                     msg_
                                     pageModel
                                     model.global
                                )
                        
                        ( newGlobalModel, newGlobalCmd ) =
                            globalModelAndCmd
                    in
                    ( { model
                        | page = updatedPageModel
                        , global = newGlobalModel
                      }
                    , Effect.batch
                        [ pageCmd, Effect.map MsgGlobal newGlobalCmd ]
                    )
            
                _ ->
                    ( model, Effect.none )
    
        MsgTimeline msg_ ->
            case
                ( model.page
                , pageData
                , Maybe.map3
                    toTriple
                    (Maybe.andThen .metadata model.current)
                    (Maybe.andThen .pageUrl model.current)
                    (Maybe.map .path model.current)
                )
            of
                ( ModelTimeline pageModel, DataTimeline thisPageData, Just ( Route.Timeline, pageUrl, justPage ) ) ->
                    let
                        ( updatedPageModel, pageCmd, globalModelAndCmd ) =
                            fooFn
                                ModelTimeline
                                MsgTimeline
                                model
                                (Route.Timeline.route.update
                                     { data = thisPageData
                                     , sharedData = sharedData
                                     , action = Nothing
                                     , routeParams = {}
                                     , path = justPage.path
                                     , url = Just pageUrl
                                     , submit =
                                         \options ->
                                             Pages.Fetcher.submit
                                                 Route.Timeline.w3_decode_ActionData
                                                 options
                                     , navigation = navigation
                                     , concurrentSubmissions =
                                         Dict.map
                                             (\mapUnpack ->
                                                  Pages.ConcurrentSubmission.map
                                                      (\mapUnpack0 ->
                                                           case mapUnpack0 of
                                                               ActionDataTimeline justActionData ->
                                                                   Just
                                                                       justActionData
                                                           
                                                               _ ->
                                                                   Nothing
                                                      )
                                             )
                                             concurrentSubmissions
                                     , pageFormState = pageFormState
                                     }
                                     msg_
                                     pageModel
                                     model.global
                                )
                        
                        ( newGlobalModel, newGlobalCmd ) =
                            globalModelAndCmd
                    in
                    ( { model
                        | page = updatedPageModel
                        , global = newGlobalModel
                      }
                    , Effect.batch
                        [ pageCmd, Effect.map MsgGlobal newGlobalCmd ]
                    )
            
                _ ->
                    ( model, Effect.none )
    
        MsgIndex msg_ ->
            case
                ( model.page
                , pageData
                , Maybe.map3
                    toTriple
                    (Maybe.andThen .metadata model.current)
                    (Maybe.andThen .pageUrl model.current)
                    (Maybe.map .path model.current)
                )
            of
                ( ModelIndex pageModel, DataIndex thisPageData, Just ( Route.Index, pageUrl, justPage ) ) ->
                    let
                        ( updatedPageModel, pageCmd, globalModelAndCmd ) =
                            fooFn
                                ModelIndex
                                MsgIndex
                                model
                                (Route.Index.route.update
                                     { data = thisPageData
                                     , sharedData = sharedData
                                     , action = Nothing
                                     , routeParams = {}
                                     , path = justPage.path
                                     , url = Just pageUrl
                                     , submit =
                                         \options ->
                                             Pages.Fetcher.submit
                                                 Route.Index.w3_decode_ActionData
                                                 options
                                     , navigation = navigation
                                     , concurrentSubmissions =
                                         Dict.map
                                             (\mapUnpack ->
                                                  Pages.ConcurrentSubmission.map
                                                      (\mapUnpack0 ->
                                                           case mapUnpack0 of
                                                               ActionDataIndex justActionData ->
                                                                   Just
                                                                       justActionData
                                                           
                                                               _ ->
                                                                   Nothing
                                                      )
                                             )
                                             concurrentSubmissions
                                     , pageFormState = pageFormState
                                     }
                                     msg_
                                     pageModel
                                     model.global
                                )
                        
                        ( newGlobalModel, newGlobalCmd ) =
                            globalModelAndCmd
                    in
                    ( { model
                        | page = updatedPageModel
                        , global = newGlobalModel
                      }
                    , Effect.batch
                        [ pageCmd, Effect.map MsgGlobal newGlobalCmd ]
                    )
            
                _ ->
                    ( model, Effect.none )


view :
    Form.Model
    -> Dict.Dict String (Pages.ConcurrentSubmission.ConcurrentSubmission ActionData)
    -> Maybe Pages.Navigation.Navigation
    -> { path : UrlPath.UrlPath, route : Maybe Route.Route }
    -> Maybe Pages.PageUrl.PageUrl
    -> Shared.Data
    -> PageData
    -> Maybe ActionData
    -> { view :
        Model
        -> { title : String, body : List (Html.Html (PagesMsg.PagesMsg Msg)) }
    , head : List Head.Tag
    }
view pageFormState concurrentSubmissions navigation page maybePageUrl globalData pageData actionData =
    case ( page.route, pageData ) of
        ( _, DataErrorPage____ data ) ->
            { view =
                \model ->
                    case model.page of
                        ModelErrorPage____ subModel ->
                            Shared.template.view
                                globalData
                                page
                                model.global
                                (\myMsg -> PagesMsg.fromMsg (MsgGlobal myMsg))
                                (View.map
                                     (\myMsg ->
                                          PagesMsg.fromMsg
                                              (MsgErrorPage____ myMsg)
                                     )
                                     (ErrorPage.view data subModel)
                                )
                    
                        _ ->
                            modelMismatchView
            , head = []
            }
    
        ( Just Route.Clusters, DataClusters data ) ->
            let
                actionDataOrNothing thisActionData =
                    case thisActionData of
                        ActionDataClusters justActionData ->
                            Just justActionData
                    
                        _ ->
                            Nothing
            in
            { view =
                \model ->
                    case model.page of
                        ModelClusters subModel ->
                            Shared.template.view
                                globalData
                                page
                                model.global
                                (\myMsg -> PagesMsg.fromMsg (MsgGlobal myMsg))
                                (View.map
                                     (PagesMsg.map MsgClusters)
                                     (Route.Clusters.route.view
                                          model.global
                                          subModel
                                          { data = data
                                          , sharedData = globalData
                                          , routeParams = {}
                                          , action =
                                              Maybe.andThen
                                                  actionDataOrNothing
                                                  actionData
                                          , path = page.path
                                          , url = maybePageUrl
                                          , submit =
                                              Pages.Fetcher.submit
                                                  Route.Clusters.w3_decode_ActionData
                                          , navigation = navigation
                                          , concurrentSubmissions =
                                              Dict.map
                                                  (\mapUnpack ->
                                                       Pages.ConcurrentSubmission.map
                                                           actionDataOrNothing
                                                  )
                                                  concurrentSubmissions
                                          , pageFormState = pageFormState
                                          }
                                     )
                                )
                    
                        _ ->
                            modelMismatchView
            , head = []
            }
    
        ( Just Route.Timeline, DataTimeline data ) ->
            let
                actionDataOrNothing thisActionData =
                    case thisActionData of
                        ActionDataTimeline justActionData ->
                            Just justActionData
                    
                        _ ->
                            Nothing
            in
            { view =
                \model ->
                    case model.page of
                        ModelTimeline subModel ->
                            Shared.template.view
                                globalData
                                page
                                model.global
                                (\myMsg -> PagesMsg.fromMsg (MsgGlobal myMsg))
                                (View.map
                                     (PagesMsg.map MsgTimeline)
                                     (Route.Timeline.route.view
                                          model.global
                                          subModel
                                          { data = data
                                          , sharedData = globalData
                                          , routeParams = {}
                                          , action =
                                              Maybe.andThen
                                                  actionDataOrNothing
                                                  actionData
                                          , path = page.path
                                          , url = maybePageUrl
                                          , submit =
                                              Pages.Fetcher.submit
                                                  Route.Timeline.w3_decode_ActionData
                                          , navigation = navigation
                                          , concurrentSubmissions =
                                              Dict.map
                                                  (\mapUnpack ->
                                                       Pages.ConcurrentSubmission.map
                                                           actionDataOrNothing
                                                  )
                                                  concurrentSubmissions
                                          , pageFormState = pageFormState
                                          }
                                     )
                                )
                    
                        _ ->
                            modelMismatchView
            , head = []
            }
    
        ( Just Route.Index, DataIndex data ) ->
            let
                actionDataOrNothing thisActionData =
                    case thisActionData of
                        ActionDataIndex justActionData ->
                            Just justActionData
                    
                        _ ->
                            Nothing
            in
            { view =
                \model ->
                    case model.page of
                        ModelIndex subModel ->
                            Shared.template.view
                                globalData
                                page
                                model.global
                                (\myMsg -> PagesMsg.fromMsg (MsgGlobal myMsg))
                                (View.map
                                     (PagesMsg.map MsgIndex)
                                     (Route.Index.route.view
                                          model.global
                                          subModel
                                          { data = data
                                          , sharedData = globalData
                                          , routeParams = {}
                                          , action =
                                              Maybe.andThen
                                                  actionDataOrNothing
                                                  actionData
                                          , path = page.path
                                          , url = maybePageUrl
                                          , submit =
                                              Pages.Fetcher.submit
                                                  Route.Index.w3_decode_ActionData
                                          , navigation = navigation
                                          , concurrentSubmissions =
                                              Dict.map
                                                  (\mapUnpack ->
                                                       Pages.ConcurrentSubmission.map
                                                           actionDataOrNothing
                                                  )
                                                  concurrentSubmissions
                                          , pageFormState = pageFormState
                                          }
                                     )
                                )
                    
                        _ ->
                            modelMismatchView
            , head = []
            }
    
        _ ->
            { view =
                \_ ->
                    { title = "Page not found"
                    , body =
                        [ Html.div
                            []
                            [ Html.text "This page could not be found." ]
                        ]
                    }
            , head = []
            }


maybeToString : Maybe String -> String
maybeToString maybeString =
    case maybeString of
        Nothing ->
            "Nothing"
    
        Just string ->
            "Just " ++ stringToString string


stringToString : String -> String
stringToString string =
    "\"" ++ string ++ "\""


nonEmptyToString : ( String, List String ) -> String
nonEmptyToString nonEmpty =
    case nonEmpty of
        ( first, rest ) ->
            "( " ++ stringToString first ++ ", [ " ++ String.join
                                                                      ", "
                                                                      (List.map
                                                                                       stringToString
                                                                                       rest
                                                                      ) ++ " ] )"


listToString : List String -> String
listToString strings =
    "[ " ++ String.join ", " (List.map stringToString strings) ++ " ]"


initErrorPage : PageData -> ( PageModel, Effect.Effect Msg )
initErrorPage pageData =
    Tuple.mapBoth
        ModelErrorPage____
        (Effect.map MsgErrorPage____)
        (ErrorPage.init
             (case pageData of
                  DataErrorPage____ errorPage ->
                      errorPage
              
                  _ ->
                      ErrorPage.notFound
             )
        )


routePatterns : ApiRoute.ApiRoute ApiRoute.Response
routePatterns =
    ApiRoute.single
        (ApiRoute.literal
             "route-patterns.json"
             (ApiRoute.succeed
                  (BackendTask.succeed
                       (Json.Encode.encode
                            0
                            (Json.Encode.list
                                 (\listUnpack ->
                                      Json.Encode.object
                                          [ ( "kind"
                                            , Json.Encode.string listUnpack.kind
                                            )
                                          , ( "pathPattern"
                                            , Json.Encode.string
                                                  listUnpack.pathPattern
                                            )
                                          ]
                                 )
                                 [ { pathPattern = "/clusters"
                                   , kind = Route.Clusters.route.kind
                                   }
                                 , { pathPattern = "/timeline"
                                   , kind = Route.Timeline.route.kind
                                   }
                                 , { pathPattern = "/"
                                   , kind = Route.Index.route.kind
                                   }
                                 ]
                            )
                       )
                  )
             )
        )


pathsToGenerateHandler =
    ApiRoute.single
        (ApiRoute.literal
             "all-paths.json"
             (ApiRoute.succeed
                  (BackendTask.map2
                       (\map2Unpack ->
                            \unpack ->
                                Json.Encode.encode
                                    0
                                    (Json.Encode.list
                                         Json.Encode.string
                                         (map2Unpack ++ List.map
                                                                (\api ->
                                                                         "/" ++ api
                                                                )
                                                                unpack
                                         )
                                    )
                       )
                       (BackendTask.map
                            (List.map
                                 (\route ->
                                      UrlPath.toAbsolute (Route.toPath route)
                                 )
                            )
                            getStaticRoutes
                       )
                       (BackendTask.map
                            List.concat
                            (BackendTask.combine
                                 (List.map
                                      ApiRoute.getBuildTimeRoutes
                                      (routePatterns :: apiPatterns :: Api.routes
                                                                                   getStaticRoutes
                                                                                   (\routesUnpack ->
                                                                                                \unpack ->
                                                                                                    ""
                                                                                   )
                                      )
                                 )
                            )
                       )
                  )
             )
        )


getStaticRoutes :
    BackendTask.BackendTask FatalError.FatalError (List Route.Route)
getStaticRoutes =
    BackendTask.map
        List.concat
        (BackendTask.combine
             [ BackendTask.map
                 (List.map (\_ -> Route.Clusters))
                 Route.Clusters.route.staticRoutes
             , BackendTask.map
                 (List.map (\_ -> Route.Timeline))
                 Route.Timeline.route.staticRoutes
             , BackendTask.map
                 (List.map (\_ -> Route.Index))
                 Route.Index.route.staticRoutes
             ]
        )


handleRoute :
    Maybe Route.Route
    -> BackendTask.BackendTask FatalError.FatalError (Maybe Pages.Internal.NotFoundReason.NotFoundReason)
handleRoute maybeRoute =
    case maybeRoute of
        Nothing ->
            BackendTask.succeed Nothing
    
        Just route ->
            case route of
                Route.Clusters ->
                    Route.Clusters.route.handleRoute
                        { moduleName = [ "Clusters" ]
                        , routePattern =
                            { segments =
                                [ Pages.Internal.RoutePattern.StaticSegment
                                    "clusters"
                                ]
                            , ending = Nothing
                            }
                        }
                        (\param -> [])
                        {}
            
                Route.Timeline ->
                    Route.Timeline.route.handleRoute
                        { moduleName = [ "Timeline" ]
                        , routePattern =
                            { segments =
                                [ Pages.Internal.RoutePattern.StaticSegment
                                    "timeline"
                                ]
                            , ending = Nothing
                            }
                        }
                        (\param -> [])
                        {}
            
                Route.Index ->
                    Route.Index.route.handleRoute
                        { moduleName = [ "Index" ]
                        , routePattern =
                            { segments =
                                [ Pages.Internal.RoutePattern.StaticSegment
                                    "index"
                                ]
                            , ending = Nothing
                            }
                        }
                        (\param -> [])
                        {}


encodeActionData : ActionData -> Bytes.Encode.Encoder
encodeActionData actionData =
    case actionData of
        ActionDataClusters thisActionData ->
            Route.Clusters.w3_encode_ActionData thisActionData
    
        ActionDataTimeline thisActionData ->
            Route.Timeline.w3_encode_ActionData thisActionData
    
        ActionDataIndex thisActionData ->
            Route.Index.w3_encode_ActionData thisActionData


subscriptions : Maybe Route.Route -> UrlPath.UrlPath -> Model -> Sub.Sub Msg
subscriptions route path model =
    Sub.batch
        [ Sub.map MsgGlobal (Shared.template.subscriptions path model.global)
        , templateSubscriptions route path model
        ]


modelMismatchView : { title : String, body : List (Html.Html msg) }
modelMismatchView =
    { title = "Model mismatch", body = [ Html.text "Model mismatch" ] }


port sendPageData :
    { oldThing : Json.Encode.Value, binaryPageData : Bytes.Bytes } -> Cmd msg


globalHeadTags :
    (Maybe { indent : Int, newLines : Bool } -> Html.Html Never -> String)
    -> BackendTask.BackendTask FatalError.FatalError (List Head.Tag)
globalHeadTags htmlToString =
    BackendTask.map
        List.concat
        (BackendTask.combine
             (Site.config.head :: List.filterMap
                                          ApiRoute.getGlobalHeadTagsBackendTask
                                          (Api.routes
                                                   getStaticRoutes
                                                   htmlToString
                                          )
             )
        )


encodeResponse :
    Pages.Internal.ResponseSketch.ResponseSketch PageData ActionData Shared.Data
    -> Bytes.Encode.Encoder
encodeResponse =
    Pages.Internal.ResponseSketch.w3_encode_ResponseSketch
        w3_encode_PageData
        w3_encode_ActionData
        Shared.w3_encode_Data


routePatterns3 : List Pages.Internal.RoutePattern.RoutePattern
routePatterns3 =
    [ { segments = [ Pages.Internal.RoutePattern.StaticSegment "clusters" ]
      , ending = Nothing
      }
    , { segments = [ Pages.Internal.RoutePattern.StaticSegment "timeline" ]
      , ending = Nothing
      }
    , { segments = [ Pages.Internal.RoutePattern.StaticSegment "index" ]
      , ending = Nothing
      }
    ]


decodeResponse :
    Bytes.Decode.Decoder (Pages.Internal.ResponseSketch.ResponseSketch PageData ActionData Shared.Data)
decodeResponse =
    Pages.Internal.ResponseSketch.w3_decode_ResponseSketch
        w3_decode_PageData
        w3_decode_ActionData
        Shared.w3_decode_Data


port hotReloadData : (Bytes.Bytes -> msg) -> Sub msg


port toJsPort : Json.Encode.Value -> Cmd msg


port fromJsPort : (Json.Decode.Value -> msg) -> Sub msg


port gotBatchSub : (Json.Decode.Value -> msg) -> Sub msg