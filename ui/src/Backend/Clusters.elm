module Backend.Clusters exposing (fetchClusters)

import Http
import Json.Decode as Decode exposing (Decoder)

type alias Cluster = { id : Int, headline : String, articleCount : Int }

clusterDecoder : Decoder Cluster
clusterDecoder =
    Decode.map3 Cluster
        (Decode.field "id" Decode.int)
        (Decode.field "headline" Decode.string)
        (Decode.field "article_count" Decode.int)

fetchClusters : String -> Cmd msg
fetchClusters url =
    Http.get
        { url = url
        , expect = Http.expectJson (\_ -> Debug.log "clusters" ()) (Decode.list clusterDecoder)
        }
