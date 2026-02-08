module Api.News exposing (Cluster, fetchClustersCmd, clusterDecoder)

import Http
import Json.Decode as Decode exposing (Decoder)

type alias Cluster =
    { id : String
    , headline : String
    , articleCount : Int
    }

clusterDecoder : Decoder Cluster
clusterDecoder =
    Decode.map3 Cluster
        (Decode.field "id" Decode.string)
        (Decode.field "headline" Decode.string)
        (Decode.field "article_count" Decode.int)

fetchClustersCmd : String -> (Result Http.Error (List Cluster) -> msg) -> Cmd msg
fetchClustersCmd url toMsg =
    Http.get
        { url = url
        , expect = Http.expectJson toMsg (Decode.list clusterDecoder)
        }
