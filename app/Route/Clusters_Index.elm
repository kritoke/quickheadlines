module Pages.Clusters exposing (Model, Msg, init, update, view)

{-| Clusters page for elm-pages
-}

import Element exposing (Element, text)


type alias Model = {}


type Msg
    = NoOp


init : ( Model, Cmd Msg )
init =
    ( {}, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


view : Model -> Element Msg
view _ =
    text "Clusters Page"
