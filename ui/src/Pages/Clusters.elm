module Pages.Clusters exposing (Model, Msg(..), init, update, view)

import Api.News exposing (Cluster, fetchClustersCmd)
import Browser
import Html exposing (Html, div, text, ul, li)
import Http
import Maybe exposing (Maybe(..))


type alias Model = { clusters : List Cluster, loading : Bool, error : Maybe String }

type Msg
    = GotClusters (Result Http.Error (List Cluster))

init : ( Model, Cmd Msg )
init =
    ( { clusters = [], loading = True, error = Nothing }
    , fetchClustersCmd "/api/clusters" GotClusters
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
