module Route.Clusters exposing (Model, Msg, init, update, view, backendTask)

{-| elm-pages Clusters page with SSR.
  
    This page prerenders clusters from the server by calling
    backend API during build. The page uses a simplified UI
    with backendTask hook.
-}

import Api.News exposing (Cluster, fetchClustersTask)
import Element exposing (Element, el, text)
import Element.Background as Background
import Element.Font as Font
import Shared exposing (Model)
import Task exposing (Task)


type alias Model =
    { clusters : List Cluster
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = NoOp


{-| elm-pages backendTask: fetch clusters during prerender.
  
    elm-pages will call this during build to get data for SSR.
    The task must produce (Model, Cmd Msg).
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
    ( { clusters = [], loading = True, error = Nothing }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


view : Shared.Model -> Model -> Element Msg
view shared model =
    let
        bg =
            case shared.theme of
                Shared.Dark ->
                    Element.rgb255 30 31 37

                Shared.Light ->
                    Element.rgb255 255 255 254
    in
    if model.loading then
        el [ Background.color bg, Font.size 14, Element.centerX, Element.centerY ]
            (text "Loading clusters...")
    else
        case model.error of
            Just err ->
                el [ Background.color bg, Font.size 14, Element.centerX, Element.centerY ]
                    (text err)

            Nothing ->
                el [ Background.color bg, Font.size 14 ]
                    (text "Clusters: " ++ String.fromInt (List.length model.clusters) ++ " items")
