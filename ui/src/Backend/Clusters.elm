
module Backend.Clusters exposing (fetchClustersTask)

import Api.News exposing (Cluster)
import Http
import Task exposing (Task)


fetchClustersTask : String -> Task Http.Error (List Cluster)
fetchClustersTask url =
    Http.toTask (Http.get { url = url, expect = Http.expectJson identity (Decode.list Api.News.clusterDecoder) })
