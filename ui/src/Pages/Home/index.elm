module Pages.Home.Index exposing (Model, Msg(..), init, update, view)

{-| elm-pages page for the Home (feeds) view.

    This file is a thin wrapper that re-uses the SPA Home_ module's logic
    so we don't duplicate state management. It exists so elm-pages can
    prerender `/` with server-side data later.

-}

import Pages.Home_ as SPAHome
import Shared exposing (Model)
import Element exposing (Element)


type alias Model = SPAHome.Model

type Msg = SPAHome.Msg


init : Shared.Model -> ( Model, Cmd Msg )
init shared =
    SPAHome.init shared


update : Msg -> Model -> ( Model, Cmd Msg )
update = SPAHome.update


view : Shared.Model -> Model -> Element Msg
view = SPAHome.view
