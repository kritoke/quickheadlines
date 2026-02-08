module Route exposing
    ( Route(..), segmentsToRoute, urlToRoute, baseUrl, routeToPath, baseUrlAsPath
    , toPath, toString, redirectTo, toLink, link, withoutBaseUrl
    )

{-|
@docs Route, segmentsToRoute, urlToRoute, baseUrl, routeToPath, baseUrlAsPath
@docs toPath, toString, redirectTo, toLink, link, withoutBaseUrl
-}


import Html
import Html.Attributes
import Server.Response
import UrlPath


{-| . -}
type Route
    = Clusters_Index
    | Index_Index
    | Timeline_Index


{-| . -}
segmentsToRoute : List String -> Maybe Route
segmentsToRoute segments =
    case segments of
    [ "clusters-index" ] ->
        Just Clusters_Index

    [ "index-index" ] ->
        Just Index_Index

    [ "timeline-index" ] ->
        Just Timeline_Index

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
             Clusters_Index ->
                 [ [ "clusters-index" ] ]
         
             Index_Index ->
                 [ [ "index-index" ] ]
         
             Timeline_Index ->
                 [ [ "timeline-index" ] ]
        )


{-| . -}
baseUrlAsPath : List String
baseUrlAsPath =
    List.filter
        (\item -> Basics.not (String.isEmpty item))
        (String.split "/" baseUrl)


{-| . -}
toPath : Route -> UrlPath.UrlPath
toPath route =
    UrlPath.fromString (String.join "/" (baseUrlAsPath ++ routeToPath route))


{-| . -}
toString : Route -> String
toString route =
    UrlPath.toAbsolute (toPath route)


{-| . -}
redirectTo : Route -> Server.Response.Response data error
redirectTo route =
    Server.Response.temporaryRedirect (toString route)


{-| . -}
toLink : (List (Html.Attribute msg) -> abc) -> Route -> abc
toLink toAnchorTag route =
    toAnchorTag
        [ Html.Attributes.href (toString route)
        , Html.Attributes.attribute "elm-pages:prefetch" ""
        ]


{-| . -}
link :
    List (Html.Attribute msg) -> List (Html.Html msg) -> Route -> Html.Html msg
link attributes children route =
    toLink (\anchorAttrs -> Html.a (anchorAttrs ++ attributes) children) route


{-| . -}
withoutBaseUrl : String -> String
withoutBaseUrl path =
    if String.startsWith baseUrl path then
        String.dropLeft (String.length baseUrl) path
    
    else
        path


splitPath path =
    List.filter (\item -> item /= "") (String.split "/" path)


maybeToList : Maybe String -> List String
maybeToList maybeString =
    case maybeString of
        Nothing ->
            []
    
        Just string ->
            [ string ]