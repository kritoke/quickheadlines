module Route exposing (Route(..), parse, toString)

import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, oneOf)


type Route
    = Home
    | Timeline
    | NotFound


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Home (Parser.s "")
        , Parser.map Timeline (Parser.s "timeline")
        ]


parse : Url -> Route
parse url =
    Parser.parse parser url
        |> Maybe.withDefault NotFound


toString : Route -> String
toString route =
    case route of
        Home ->
            "/"

        Timeline ->
            "/timeline"

        NotFound ->
            "/not-found"
