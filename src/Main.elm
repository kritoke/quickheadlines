port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import AppEffect exposing (Effect(..))
import Element exposing (Element)
import Html.Attributes
import Html.Events
import Pages.Home_ as Home
import Pages.Timeline as Timeline
import Page exposing (Page)
import Shared exposing (Shared, Size)
import Types exposing (Theme(..))
import Task
import Time
import Url exposing (Url)
import View exposing (View)


main : Program { width : Int, height : Int, prefersDark : Bool } Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type alias Model =
    { key : Nav.Key
    , url : Url
    , shared : Shared
    , page : PageModel
    }


type PageModel
    = Home Home.Model
    | Timeline Timeline.Model
    | NotFound


type Msg
    = UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | SharedMsg Shared.Msg
    | HomeMsg Home.Msg
    | TimelineMsg Timeline.Msg


init : { width : Int, height : Int, prefersDark : Bool } -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        initialTheme =
            if flags.prefersDark then
                Types.Dark

            else
                Types.Light

        ( shared, sharedEffect ) =
            Shared.init (Url.toString url) key flags.width flags.height initialTheme

        ( pageModel, pageEffect ) =
            initPage url shared
    in
    ( { key = key
      , url = url
      , shared = shared
      , page = pageModel
      }
    , Cmd.batch
        [ AppEffect.toCmd { key = key } (AppEffect.map SharedMsg sharedEffect)
        , AppEffect.toCmd { key = key } pageEffect
        ]
    )


initPage : Url -> Shared -> ( PageModel, AppEffect.Effect Msg )
initPage url shared =
    if url.path == "/" then
        let
            ( homeModel, homeEffect ) =
                Home.init shared ()
        in
        ( Home homeModel
        , AppEffect.map HomeMsg homeEffect
        )

    else if url.path == "/timeline" then
        let
            ( timelineModel, timelineEffect ) =
                Timeline.init shared ()
        in
        ( Timeline timelineModel
        , AppEffect.map TimelineMsg timelineEffect
        )

    else
        ( NotFound, AppEffect.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChanged url ->
            let
                ( pageModel, pageEffect ) =
                    initPage url model.shared
            in
            ( { model | url = url, page = pageModel }
            , AppEffect.toCmd { key = model.key } pageEffect
            )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        SharedMsg sharedMsg ->
            let
                ( shared, sharedEffect ) =
                    Shared.update sharedMsg model.shared
            in
            ( { model | shared = shared }
            , Cmd.map SharedMsg (AppEffect.toCmd { key = model.key } sharedEffect)
            )

        HomeMsg homeMsg ->
            case model.page of
                Home homeModel ->
                    case homeMsg of
                        Home.ToggleThemeRequested ->
                            let
                                ( shared, sharedEffect ) =
                                    Shared.update Shared.ToggleTheme model.shared

                                themeStr =
                                    case shared.theme of
                                        Types.Light ->
                                            "light"

                                        Types.Dark ->
                                            "dark"
                            in
                            ( { model | shared = shared }
                            , Cmd.batch
                                [ Cmd.map SharedMsg (AppEffect.toCmd { key = model.key } sharedEffect)
                                , saveTheme themeStr
                                ]
                            )

                        _ ->
                            let
                                ( newHomeModel, homeEffect ) =
                                    Home.update model.shared homeMsg homeModel
                            in
                            ( { model | page = Home newHomeModel }
                            , Cmd.map HomeMsg (AppEffect.toCmd { key = model.key } homeEffect)
                            )

                _ ->
                    ( model, Cmd.none )

        TimelineMsg timelineMsg ->
            case model.page of
                Timeline timelineModel ->
                    case timelineMsg of
                        Timeline.ToggleThemeRequested ->
                            let
                                ( shared, sharedEffect ) =
                                    Shared.update Shared.ToggleTheme model.shared

                                themeStr =
                                    case shared.theme of
                                        Types.Light ->
                                            "light"

                                        Types.Dark ->
                                            "dark"
                            in
                            ( { model | shared = shared }
                            , Cmd.batch
                                [ Cmd.map SharedMsg (AppEffect.toCmd { key = model.key } sharedEffect)
                                , saveTheme themeStr
                                ]
                            )

                        _ ->
                            let
                                ( newTimelineModel, timelineEffect ) =
                                    Timeline.update model.shared timelineMsg timelineModel
                            in
                            ( { model | page = Timeline newTimelineModel }
                            , Cmd.map TimelineMsg (AppEffect.toCmd { key = model.key } timelineEffect)
                            )

                _ ->
                    ( model, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    let
        { title, body } =
            case model.page of
                Home homeModel ->
                    Home.view model.shared homeModel
                        |> View.map HomeMsg

                Timeline timelineModel ->
                    Timeline.view model.shared timelineModel
                        |> View.map TimelineMsg

                NotFound ->
                    { title = "Not Found"
                    , body = Element.text "Page not found"
                    }
    in
    { title = title
    , body =
        [ Element.layout
            [ Element.width Element.fill
            , Element.height Element.fill
            , Element.htmlAttribute (Html.Attributes.style "min-height" "100vh")
            ]
            body
        ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ onResize (SharedMsg << Shared.WindowResized)
        , Shared.subscriptions model.shared
            |> Sub.map SharedMsg
        , case model.page of
            Home homeModel ->
                Home.subscriptions homeModel
                    |> Sub.map HomeMsg

            Timeline timelineModel ->
                Timeline.subscriptions model.shared timelineModel
                    |> Sub.map TimelineMsg

            NotFound ->
                Sub.none
        ]


port onResize : (Size -> msg) -> Sub msg


port saveTheme : String -> Cmd msg
