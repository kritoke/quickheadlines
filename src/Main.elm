module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Effect exposing (Effect, map)
import Element exposing (Element)
import Html
import Pages.Home_ as Home
import Page exposing (Page)
import Shared exposing (Shared)
import Url exposing (Url)
import View exposing (View)


main : Program () Model Msg
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
    | NotFound


type Msg
    = UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | SharedMsg Shared.Msg
    | HomeMsg Home.Msg


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        ( shared, sharedEffect ) =
            Shared.init (Url.toString url) key

        ( pageModel, pageEffect ) =
            initPage url shared
    in
    ( { key = key
      , url = url
      , shared = shared
      , page = pageModel
      }
    , Cmd.batch
        [ Effect.toCmd { key = key } (Effect.map SharedMsg sharedEffect)
        , Effect.toCmd { key = key } pageEffect
        ]
    )


initPage : Url -> Shared -> ( PageModel, Effect Msg )
initPage url shared =
    if url.path == "/" then
        let
            ( homeModel, homeEffect ) =
                Home.init shared ()
        in
        ( Home homeModel
        , Effect.map HomeMsg homeEffect
        )

    else
        ( NotFound, Effect.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChanged url ->
            let
                ( pageModel, pageEffect ) =
                    initPage url model.shared
            in
            ( { model | url = url, page = pageModel }
            , Effect.toCmd { key = model.key } pageEffect
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
            , Effect.toCmd { key = model.key } (Effect.map SharedMsg sharedEffect)
            )

        HomeMsg homeMsg ->
            case model.page of
                Home homeModel ->
                    let
                        ( newHomeModel, homeEffect ) =
                            Home.update model.shared homeMsg homeModel
                    in
                    ( { model | page = Home newHomeModel }
                    , Effect.toCmd { key = model.key } (Effect.map HomeMsg homeEffect)
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

                NotFound ->
                    { title = "Not Found"
                    , body = [ Html.text "Page not found" ]
                    }
    in
    { title = title
    , body = body
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Shared.subscriptions model.shared
            |> Sub.map SharedMsg
        , case model.page of
            Home homeModel ->
                Home.subscriptions homeModel
                    |> Sub.map HomeMsg

            NotFound ->
                Sub.none
        ]
