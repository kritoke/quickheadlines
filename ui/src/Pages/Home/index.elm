module Pages.Home exposing (main)

import Browser
import Html exposing (Html, div, text)

main : Program () () ()
main =
    Browser.sandbox { init = (), update = \_ m -> m, view = view }

view : () -> Html msg
view _ =
    div [] [ text "QuickHeadlines - elm-pages v3 scaffold (Home)" ]
