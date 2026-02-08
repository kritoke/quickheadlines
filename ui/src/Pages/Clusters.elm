module Pages.Clusters exposing (Model, Msg(..), init, update, view)

import Api.News exposing (Cluster)
import Element exposing (Element, el, text, ul, li)
import Element.Background as Background
import Element.Font as Font
import Shared exposing (Model)
import Theme exposing (surfaceColor)


type alias Model = { clusters : List Cluster, loading : Bool, error : Maybe String }

type Msg
    = NoOp

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
        bg = surfaceColor shared.theme
    in
    if model.loading then
        el [ Background.color bg, Font.size 14 ] (text "Loading clusters...")
    else
        case model.error of
            Just err ->
                el [ Background.color bg, Font.size 14 ] (text err)

            Nothing ->
                el [ Background.color bg, Font.size 14 ]
                    (ul [] (List.map (\c -> li [] [ text c.headline ]) model.clusters))
