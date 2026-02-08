module Pages.Timeline.Index exposing (Model, Msg(..), init, subscriptions, update, view)

{-| elm-pages wrapper for the Timeline page. Re-uses SPA Timeline logic
    so the SPA continues to function while elm-pages can prerender the page.
-}

import Pages.Timeline as SPATimeline
import Shared exposing (Model)
import Element exposing (Element)


type alias Model = SPATimeline.Model

type Msg = SPATimeline.Msg


init : ( Model, Cmd Msg )
init =
    SPATimeline.init


subscriptions : Model -> Sub Msg
subscriptions = SPATimeline.subscriptions


update : Msg -> Model -> ( Model, Cmd Msg )
update = SPATimeline.update


view : Shared.Model -> Model -> Element Msg
view = SPATimeline.view
