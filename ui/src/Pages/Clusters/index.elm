module Pages.Clusters.Index exposing (Model, Msg(..), init, update, view)

{-| elm-pages wrapper for the Clusters page. Uses the new Pages.Clusters
    component so we can prerender `/clusters`.
-}

import Pages.Clusters as Clusters
import Shared exposing (Model)
import Element exposing (Element)
import Api.News exposing (fetchClustersTask)
import Task exposing (Task)


type alias Model = Clusters.Model

type Msg = Clusters.Msg


{-| elm-pages backendTask hook

    elm-pages recognizes a `backendTask` value exported from a page module and
    will execute it during prerender. The task must produce (Model, Cmd Msg)
    or a shape consumable by the page. Here we run a Task that fetches clusters
    from the backend API and return the data so the page can render server-side.
-}

backendTask : Task x ( Model, Cmd Msg )
backendTask =
    fetchClustersTask "/api/clusters"
        |> Task.map
            (\clusters ->
                ( { clusters = clusters, loading = False, error = Nothing }
                , Cmd.none
                )
            )


init : ( Model, Cmd Msg )
init =
    Clusters.init


update : Msg -> Model -> ( Model, Cmd Msg )
update = Clusters.update


view : Shared.Model -> Model -> Element Msg
view = Clusters.view
