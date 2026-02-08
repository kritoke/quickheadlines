module Route exposing ( Route(..), segmentsToRoute, urlToRoute, baseUrl, routeToPath, baseUrlAsPath
    , toPath, toString, redirectTo, toLink, link, withoutBaseUrl
    , Index(..)
    , Timeline(..)
    , Clusters(..)


{-| @docs Route, segmentsToRoute, urlToRoute, baseUrl, routeToPath, baseUrlAsPath
@docs toPath, toString, redirectTo, toLink, link, withoutBaseUrl
@docs Index(..)
@docs Timeline(..)
@docs Clusters(..)
-}


import Html
import Html.Attributes
import Server.Response
import UrlPath


{-| . -}
type Route
    = Index
    | Timeline
    | Clusters


{-| . -}
type Index
    = Index


{-| . -}
type Timeline
    = Timeline


{-| . -}
type Clusters
    = Clusters


{-| . -}
segmentsToRoute : List String -> Maybe Route
segmentsToRoute segments =
    case segments of
        [] ->
            Just Index

        [ "timeline" ] ->
            Just Timeline

        [ "clusters" ] ->
            Just Clusters

        _ ->
            Nothing


{-| . -}
urlToRoute : { url | path : String } -> Maybe Route
urlToRoute url =
    segmentsToRoute (splitPath url.path)


{-| . -}
baseUrl : String
baseUrl =
    "/"


{-| . -}
routeToPath : Route -> List String
routeToPath route =
    List.concat
        (case route of
            Index ->
                []

            Timeline ->
                [ "timeline" ]

            Clusters ->
                [ "clusters" ]
        )


{-| . -}
toPath : Route -> String
toPath route =
    "/" ++ String.join "/" (routeToPath route)


{-| . -}
toString : Route -> String
toString route =
    case route of
        Index ->
            "/"

        Timeline ->
            "/timeline"

        Clusters ->
            "/clusters"


{-| . -}
redirectTo : Route -> { redirect : String }
redirectTo route =
    { redirect = toPath route }


{-| . -}
toLink : Route -> { link : String }
toLink route =
    { link = toPath route }


{-| . -}
link : Route -> List (Html.Attribute msg)
link route =
    case route of
        Index ->
            [ Html.Attributes.href "/" ]

        Timeline ->
            [ Html.Attributes.href "/timeline" ]

        Clusters ->
            [ Html.Attributes.href "/clusters" ]


{-| . -}
withoutBaseUrl : Route -> String
withoutBaseUrl route =
    String.dropLeft 1 (toPath route)
