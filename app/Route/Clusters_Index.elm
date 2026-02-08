module Pages.Clusters exposing (Model, Msg(..), init, update, view, subscriptions)

{-| Clusters page for elm-pages
-}

import Element exposing (Element, text, column, row, paragraph, link, el, image)
import Element.Background as Background
import Element.Font as Font
import Element.Border as Border
import Platform.Sub as Sub
import Maybe
import Http
import Json.Decode as Decode exposing (Decoder)
import Shared exposing (Model as SharedModel, Theme)
import Theme exposing (textColor, mutedColor, surfaceColor)



type alias Story =
    { id : String
    , title : String
    , link : String
    , feed_title : String
    }


type alias Cluster =
    { id : String
    , representative : Story
    , cluster_size : Int
    }


type alias Model =
    { clusters : List Cluster
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = GotClusters (Result Http.Error (List Cluster))
    | NoOp


init : SharedModel -> ( Model, Cmd Msg )
init _shared =
    ( { clusters = [], loading = True, error = Nothing }
    , fetchClusters
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotClusters (Ok clusters) ->
            ( { model | clusters = clusters, loading = False, error = Nothing }
            , Cmd.none
            )

        GotClusters (Err _) ->
            ( { model | loading = False, error = Just "Failed to load clusters" }
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )


view : SharedModel -> Model -> Element Msg
view shared model =
    let
        txt = textColor shared.theme
        muted = mutedColor shared.theme
    in
    if model.loading then
        el [ Font.size 16, Font.color muted ] (text "Loading clusters...")
    else if model.error /= Nothing then
        el [ Font.size 14, Font.color muted ] (text (Maybe.withDefault "" model.error))
    else
        column [ Background.color (surfaceColor shared.theme) ]
            (List.map clusterView model.clusters)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


clusterView : Cluster -> Element Msg
clusterView cluster =
    row [ Border.rounded 8, Border.width 1 ]
        [ paragraph [ Font.size 16 ] [ link [] { url = cluster.representative.link, label = text cluster.representative.title } ]
        , paragraph [ Font.size 13 ] [ text (" (" ++ String.fromInt cluster.cluster_size ++ ")") ]
        ]


-- HTTP / Decoders

storyDecoder : Decoder Story
storyDecoder =
    Decode.map4 Story
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "link" Decode.string)
        (Decode.field "feed_title" Decode.string)


clusterDecoder : Decoder Cluster
clusterDecoder =
    Decode.map3 Cluster
        (Decode.field "id" Decode.string)
        (Decode.field "representative" storyDecoder)
        (Decode.field "cluster_size" Decode.int)


clustersDecoder : Decoder (List Cluster)
clustersDecoder =
    Decode.field "clusters" (Decode.list clusterDecoder)


fetchClusters : Cmd Msg
fetchClusters =
    Http.get
        { url = "/api/clusters"
        , expect = Http.expectJson GotClusters clustersDecoder
        }
