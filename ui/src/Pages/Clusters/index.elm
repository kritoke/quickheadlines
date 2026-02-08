module Pages.Clusters.Index exposing (Model, Msg(..), init, update, view)

{-| elm-pages wrapper for the Clusters page. Uses the new Pages.Clusters
    component so we can prerender `/clusters`.
-}

import Pages.Clusters as Clusters
import Shared exposing (Model)
import Element exposing (Element)


type alias Model = Clusters.Model

type Msg = Clusters.Msg


init : ( Model, Cmd Msg )
init =
    Clusters.init


update : Msg -> Model -> ( Model, Cmd Msg )
update = Clusters.update


view : Shared.Model -> Model -> Element Msg
view = Clusters.view
