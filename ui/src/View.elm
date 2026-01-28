module View exposing (View)

import Html exposing (Html)


type alias View msg =
    { title : String
    , body : List (Html msg)
    }
