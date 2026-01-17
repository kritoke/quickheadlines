module Components.FeedBody exposing (view)

import Element exposing (..)
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Types exposing (FeedItem)


view : List FeedItem -> Element msg
view items =
    column
        [ width fill
        , height fill
        , spacing 8
        , padding 12
        , scrollbarY
        ]
        (List.map feedItemView items)


feedItemView : FeedItem -> Element msg
feedItemView item =
    row
        [ width fill
        , spacing 8
        ]
        [ el
            [ Font.size 14
            , Font.color (rgb255 148 163 184)
            , width (px 6)
            , height fill
            , Border.width 2
            , Border.color (rgb255 226 232 240)
            , Border.roundEach { topLeft = 3, topRight = 3, bottomLeft = 3, bottomRight = 3 }
            ]
            Element.none
        , link
            [ width fill
            , Font.size 14
            , Font.color (rgb255 51 65 85)
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "line-height" "1.4")
            , mouseOver [ Font.color (rgb255 37 99 235) ]
            ]
            { url = item.link
            , label = text item.title
            }
        ]
