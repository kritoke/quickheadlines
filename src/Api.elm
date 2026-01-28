module Api exposing (getFeeds, getFeedMore, getVersion)

import Decoders exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, list, map, maybe, nullable, string, succeed)
import Time exposing (Posix)
import Types exposing (..)


baseUrl : String
baseUrl =
    ""


getFeeds : String -> (Result Http.Error { tabs : List Tab, activeTab : String, feeds : List Feed } -> Msg) -> Cmd Msg
getFeeds tab expectMsg =
    Http.get
        { url = baseUrl ++ "/api/feeds?tab=" ++ tab
        , expect = Http.expectJson expectMsg feedsPageDecoder
        }


getFeedMore : String -> Int -> (Result Http.Error Feed -> Msg) -> Cmd Msg
getFeedMore url offset expectMsg =
    Http.get
        { url = baseUrl ++ "/api/feed_more?url=" ++ url ++ "&limit=10&offset=" ++ String.fromInt offset
        , expect = Http.expectJson expectMsg feedDecoder
        }


getVersion : (Result Http.Error Posix -> Msg) -> Cmd Msg
getVersion expectMsg =
    Http.get
        { url = baseUrl ++ "/api/version"
        , expect = Http.expectJson expectMsg versionDecoder
        }


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "Invalid URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Server returned status: " ++ String.fromInt status

        Http.BadBody message ->
            "Invalid response: " ++ message
