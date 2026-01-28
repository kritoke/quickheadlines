module View exposing (View, map)

import Element exposing (Element)


type alias View msg =
    { title : String
    , body : Element msg
    }


map : (msg1 -> msg2) -> View msg1 -> View msg2
map fn view =
    { title = view.title
    , body = Element.map fn view.body
    }
