module Pages.ViewIcon exposing (viewIcon)

import Element exposing (..)
import Html
import Html.Attributes


viewIcon : String -> String -> Element msg
viewIcon url siteName =
    let
        iconUrl =
            if String.isEmpty url || url == "null" then
                "https://www.google.com/s2/favicons?sz=32&domain_url=" ++ siteName

            else
                url
    in
    html
        (Html.img
            [ Html.Attributes.src iconUrl
            , Html.Attributes.style "width" "14px"
            , Html.Attributes.style "height" "14px"
            , Html.Attributes.style "display" "inline"
            , Html.Attributes.style "vertical-align" "middle"
            , Html.Attributes.style "margin-right" "4px"
            , Html.Attributes.style "margin-bottom" "2px"
            ]
            []
        )
