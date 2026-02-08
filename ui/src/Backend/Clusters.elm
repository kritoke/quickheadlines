
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
            if n <= 0 then
                fetchClustersTask url
            else
                Task.andThen
                    (es ->
                        case res of
                            Ok v ->
                                Task.succeed v

                            Err _ ->
                                attempt (n - 1)
                    )
                    (Task.attempt identity (fetchClustersTask url))
    in
    attempt retries
