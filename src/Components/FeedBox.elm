module Components.FeedBox exposing (view)

import Components.FeedBody as FeedBody
import Components.FeedHeader as FeedHeader
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Html.Attributes
import Theme exposing (cardColor)
import Time exposing (Posix)
import Types exposing (Feed, Theme(..))


view : Int -> Posix -> Theme -> Feed -> Element msg
view windowWidth now theme feed =
    let
        isMobile =
            windowWidth < 768

        boxHeight =
            if isMobile then
                fill

            else if windowWidth >= 1024 then
                px 400

            else
                px 368
    in
    column
        [ htmlAttribute (Html.Attributes.class "feed-box")
        , height boxHeight
        , Border.rounded 12
        , Background.color (cardColor theme)
        , width fill
        , htmlAttribute (Html.Attributes.style "overflow" "hidden")
        , htmlAttribute (Html.Attributes.style "display" "flex")
        , htmlAttribute (Html.Attributes.style "flex-direction" "column")
        , htmlAttribute (Html.Attributes.style "align-items" "stretch")
        ]
        [ FeedHeader.view theme feed
        , FeedBody.view windowWidth now theme feed.items
        ]
