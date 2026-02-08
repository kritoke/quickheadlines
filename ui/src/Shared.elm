module Shared exposing (layout)

import Html exposing (Html, div)
import Html.Attributes as Attr


layout : List (Html msg) -> Html msg
layout children =
    div [ Attr.class "qh-app" ] children
