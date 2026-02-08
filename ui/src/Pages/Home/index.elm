
module Pages.Home exposing (Model, Msg, main)

import Api.News exposing (Cluster)
import Backend.Clusters as BC
import Browser
import Html exposing (Html, div, text, ul, li)
import Http
import Task
import Maybe exposing (Maybe(..))


type alias Model = { clusters : List Cluster, loading : Bool, error : Maybe String }

type Msg
    = GotClusters (Result Http.Error (List Cluster))

init : ( Model, Cmd Msg )
init =
    ( { clusters = [], loading = True, error = Nothing }
    , Task.attempt GotClusters (BC.fetchClustersTaskWithRetry 2 "/api/clusters")
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotClusters (Ok ls) ->
            ( { model | clusters = ls, loading = False, error = Nothing }, Cmd.none )

        GotClusters (Err _) ->
            ( { model | loading = False, error = Just "Failed to fetch clusters" }, Cmd.none )

view : Model -> Html Msg
view model =
    if model.loading then
        div [] [ text "Loading clusters..." ]
    else
        case model.error of
            Just err ->
                div [] [ text err ]

            Nothing ->
                div []
                    [ ul [] (List.map (\c -> li [] [ text c.headline ]) model.clusters) ]

main : Program () Model Msg
main =
    Browser.element { init = \_ -> init, update = update, subscriptions = \_ -> Sub.none, view = view }
