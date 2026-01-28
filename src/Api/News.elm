module Api.News exposing (fetchClusters, Cluster)

import Http
import Json.Decode exposing (Decoder, field, int, list, map4, string)


type alias Cluster =
    { id : String
    , title : String
    , timestamp : String
    , sourceCount : Int
    }


decoder : Decoder Cluster
decoder =
    map4 Cluster
        (field "id" string)
        (field "title" string)
        (field "timestamp" string)
        (field "source_count" int)


fetchClusters : Cmd Msg
fetchClusters =
    Http.get
        { url = "/api/clusters"
        , expect = Http.expectJson GotClusters (list decoder)
        }


type Msg
    = GotClusters (Result Http.Error (List Cluster))
