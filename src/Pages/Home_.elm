module Pages.Home_ exposing (Model, Msg, page)

import Effect exposing (Effect)
import Html exposing (Html, div, h1, text)
import Page exposing (Page)
import View exposing (View)


page : Page Model Msg
page =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}, Effect.none )


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )


view : Model -> View Msg
view model =
    { title = "QuickHeadlines"
    , body =
        [ div []
            [ h1 [] [ text "QuickHeadlines" ]
            , text "Home page - Elm Land migration in progress"
            ]
        ]
    }
