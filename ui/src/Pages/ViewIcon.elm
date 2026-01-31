module Pages.ViewIcon exposing (viewIcon)

import Element exposing (..)
import Element.Border as Border

viewIcon : String -> String -> Element msg
viewIcon url siteName =
    image
        [ width (px 16)
        , height (px 16)
        , Border.rounded 2
        , centerY
        ]
        { src = url, description = siteName }
