module View exposing (View)

import Element exposing (Element)


type alias View msg =
    { title : String
    , body : List (Element msg)
    }
