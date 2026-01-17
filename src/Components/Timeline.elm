module Components.Timeline exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Types exposing (Theme(..), TimelineItem, TimelineModel)


view : Int -> Theme -> TimelineModel -> Element msg
view windowWidth theme model =
    column
        [ width fill
        , spacing 16
        ]
        (List.map (timelineItem theme) model.items)


timelineItem : Theme -> TimelineItem -> Element msg
timelineItem theme item =
    column
        [ width fill
        , spacing 8
        , padding 16
        , Background.color (rgb255 255 255 255)
        , Border.rounded 8
        , Border.width 1
        , Border.color (rgb255 229 231 235)
        ]
        [ row
            [ spacing 12
            , Font.size 14
            , Font.color (rgb255 107 114 128)
            ]
            [ text item.feedTitle
            , text "•"
            , text "timestamp"
            ]
        , el
            [ Font.size 18
            , Font.medium
            , Font.color (rgb255 30 41 59)
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            ]
            (text item.title)
        ]
