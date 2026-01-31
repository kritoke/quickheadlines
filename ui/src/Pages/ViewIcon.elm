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
        [ width (px 18)
        , height (px 18)
        , Border.rounded 3
        , centerY
        , Element.padding 2
        , htmlAttribute (Html.Attributes.class "qh-favicon")
        ]
        { src = iconUrl, description = siteName }
