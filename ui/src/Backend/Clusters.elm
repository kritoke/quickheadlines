module Backend.Clusters exposing (fetchClustersTask, fetchClustersTaskWithRetry)

import Api.News exposing (Cluster)
import Http
import Json.Decode as Decode
import Task exposing (Task)


-- Basic fetch converted to Task
fetchClustersTask : String -> Task Http.Error (List Cluster)
fetchClustersTask url =
    Http.toTask (Http.get { url = url, expect = Http.expectJson identity (Decode.list Api.News.clusterDecoder) })


-- Retry helper: attempt the task up to `retries` times.
fetchClustersTaskWithRetry : Int -> String -> Task Http.Error (List Cluster)
fetchClustersTaskWithRetry retries url =
    let
        attempt n =
            fetchClustersTask url
                |> Task.onError (\err ->
                    if n <= 0 then
                        Task.fail err
                    else
                        attempt (n - 1)
                )
    in
    attempt retries
