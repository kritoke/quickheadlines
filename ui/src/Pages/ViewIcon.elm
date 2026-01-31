module Pages.ViewIcon exposing (viewIcon)

import Element exposing (..)
import Element.Border as Border

viewIcon : String -> String -> Element msg
viewIcon url siteName =
    image
        [ width (px 14)
        , height (px 14)
        , Border.rounded 2
        , alignTop
        , moveDown 2
        ]
        { src = url, description = siteName }
