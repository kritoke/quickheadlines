module Pages.Index exposing (Model, Msg, init, update, view)

{-| Home page for elm-pages (Index route)
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
    text "QuickHeadlines Home"
