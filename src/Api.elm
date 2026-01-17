module Api exposing (..)

import Decoders exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, list, map, maybe, nullable, string, succeed)
import Time exposing (Posix)
import Types exposing (..)



-- Base URL for API


baseUrl : String
baseUrl =
    ""



-- Get feeds for a specific tab


getFeeds : String -> Cmd Msg
getFeeds tab =
    Http.get
        { url = baseUrl ++ "/feeds?tab=" ++ tab
        , expect = Http.expectJson (Result.mapError GotFeeds feedsDecoder)
        }



-- Get timeline items


getTimelineItems : Int -> Int -> Cmd Msg
getTimelineItems limit offset =
    Http.get
        { url = baseUrl ++ "/timeline_items?limit=" ++ String.fromInt limit ++ "&offset=" ++ String.fromInt offset
        , expect = Http.expectJson (Result.mapError GotTimelineItems timelineItemsDecoder)
        }



-- Get more items for a specific feed


getFeedMore : String -> Int -> Cmd Msg
getFeedMore url offset =
    Http.get
        { url = baseUrl ++ "/feed_more?url=" ++ url ++ "&limit=10&offset=" ++ String.fromInt offset
        , expect = Http.expectJson (Result.mapError (GotMoreItems url) feedDecoder)
        }



-- Get version for update checking


getVersion : Cmd Msg
getVersion =
    Http.get
        { url = baseUrl ++ "/version"
        , expect = Http.expectString (Result.mapError GotLastUpdated versionDecoder)
        }



-- Helper to map Http.Error to our custom error type


type alias ApiError =
    { message : String
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

        Http.BadStatus status _ ->
            "Server returned status: " ++ String.fromInt status

        Http.BadBody message ->
            "Invalid response: " ++ message



-- Map Http.Error to our error type


mapError : (a -> msg) -> Http.Error -> Result Http.Error a
mapError toMsg httpError =
    case httpError of
        Ok value ->
            Ok value

        Err error ->
            Err error
