module Theme exposing (..)

import Element exposing (Attribute, Color, rgb255, htmlAttribute)
import Html.Attributes
import ThemeTypography as Ty
import Shared exposing (Theme(..))


semantic : String -> Attribute msg
semantic name =
    htmlAttribute (Html.Attributes.attribute "data-semantic" name)


testId : String -> Attribute msg
testId name =
    htmlAttribute (Html.Attributes.attribute "data-name" name)



type alias Colors =
    { background : Color
    , surface : Color
    , card : Color
    , border : Color
    , text : Color
    , muted : Color
    }


themeToColors : Theme -> Colors
themeToColors theme =
    case theme of
        Dark ->
            { background = rgb255 18 18 18
            , surface = rgb255 24 24 24
            , card = rgb255 30 30 30
            , border = rgb255 55 55 55
            , text = rgb255 255 255 255
            , muted = rgb255 148 163 184
            }

        Light ->
            { background = rgb255 249 250 251
            , surface = rgb255 249 250 251
            , card = rgb255 255 255 255
            , border = rgb255 229 231 235
            , text = rgb255 17 24 39
            , muted = rgb255 107 114 128
            }


darkBg : Color
darkBg =
    rgb255 18 18 18


lumeOrange : Color
lumeOrange =
    rgb255 255 165 0


textColor : Theme -> Color
textColor theme =
    case theme of
        Dark ->
            rgb255 255 255 255

        Light ->
            rgb255 17 24 39


mutedColor : Theme -> Color
mutedColor theme =
    case theme of
        Dark ->
            rgb255 148 163 184

        Light ->
            rgb255 107 114 128


surfaceColor : Theme -> Color
surfaceColor theme =
    case theme of
        Dark ->
            rgb255 24 24 24

        Light ->
            rgb255 249 250 251


cardColor : Theme -> Color
cardColor theme =
    case theme of
        Dark ->
            rgb255 30 30 30

        Light ->
            rgb255 255 255 255


borderColor : Theme -> Color
borderColor theme =
    case theme of
        Dark ->
            rgb255 55 55 55

        Light ->
            rgb255 229 231 235


errorColor : Color
errorColor =
    rgb255 239 68 68


tabActiveBg : Theme -> Color
tabActiveBg theme =
    case theme of
        Dark ->
            rgb255 40 40 40

        Light ->
            rgb255 243 244 246


tabHoverBg : Theme -> Color
tabHoverBg theme =
    case theme of
        Dark ->
            rgb255 35 35 40

        Light ->
            rgb255 229 231 235


tabActiveText : Color
tabActiveText =
    lumeOrange


tabInactiveText : Theme -> Color
tabInactiveText theme =
    case theme of
        Dark ->
            rgb255 148 163 184

        Light ->
            rgb255 75 85 99


metadataStyle : Theme -> List (Attribute msg)
metadataStyle theme =
    [ Font.size 14
    , Font.color (mutedColor theme)
    ]
