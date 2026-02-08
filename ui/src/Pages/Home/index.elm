
module Pages.Home exposing (Model, Msg, main)

import Api.News exposing (Cluster, fetchClustersCmd)
import Browser
import Html exposing (Html, div, text, ul, li)
import Http


type alias Model = { clusters : List Cluster, loading : Bool }

type Msg
    = GotClusters (Result Http.Error (List Cluster))

init : ( Model, Cmd Msg )
init =
    ( { clusters = [], loading = True }
    , fetchClustersCmd "/api/clusters" GotClusters
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotClusters (Ok ls) ->
            ( { model | clusters = ls, loading = False }, Cmd.none )

        GotClusters (Err _) ->
            ( { model | loading = False }, Cmd.none )

view : Model -> Html Msg
view model =
    if model.loading then
        div [] [ text "Loading clusters..." ]
    else
        div []
            [ ul [] (List.map (\c -> li [] [ text c.headline ]) model.clusters) ]

main : Program () Model Msg
main =
    Browser.element { init = \_ -> init, update = update, subscriptions = \_ -> Sub.none, view = view }
