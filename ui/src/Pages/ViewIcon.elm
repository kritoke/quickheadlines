module Pages.ViewIcon exposing (viewIcon)

import Element exposing (..)
import Element.Border as Border

viewIcon : String -> String -> Element msg
viewIcon url siteName =
    let
        iconUrl =
            if String.isEmpty url || url == "null" then
                "https://www.google.com/s2/favicons?sz=32&domain_url=" ++ siteName

            else
                url
    in
    image
        [ width (px 14)
        , height (px 14)
        , Border.rounded 2
        , centerY
        ]
        { src = iconUrl, description = siteName }
