module Theme exposing
    ( Theme
    , ThemeColors
    , borderColor
    , cardColor
    , feedHeaderColor
    , feedHeaderTextColor
    , getThemeColors
    , scrollShadowDark
    , scrollShadowLight
    , surfaceColor
    , tabActiveBgColor
    , tabActiveTextColor
    , tabHoverBgColor
    , tabInactiveColor
    , textColor
    )

import Element exposing (Color, rgb255, rgba255)
import Types exposing (Theme(..))



-- Re-export Theme type from Types


type alias Theme =
    Types.Theme



-- Light Mode Colors


surfaceLight : Color
surfaceLight =
    rgb255 249 250 251


cardLight : Color
cardLight =
    rgb255 255 255 255


borderLight : Color
borderLight =
    rgb255 229 231 235


textLight : Color
textLight =
    rgb255 30 41 59



-- Dark Mode Colors


surfaceDark : Color
surfaceDark =
    rgb255 17 24 39


cardDark : Color
cardDark =
    rgb255 17 24 39


borderDark : Color
borderDark =
    rgb255 51 65 85


textDark : Color
textDark =
    rgb255 226 232 240



-- Feed Header Colors


feedHeaderBgLight : Color
feedHeaderBgLight =
    rgb255 243 244 246


feedHeaderBgDark : Color
feedHeaderBgDark =
    rgb255 31 41 55


feedHeaderTextLight : Color
feedHeaderTextLight =
    rgb255 31 41 55


feedHeaderTextDark : Color
feedHeaderTextDark =
    rgb255 255 255 255



-- Tab Colors


tabInactiveLight : Color
tabInactiveLight =
    rgb255 100 116 139


tabHoverBgLight : Color
tabHoverBgLight =
    rgb255 241 245 249


tabActiveBgLight : Color
tabActiveBgLight =
    rgb255 239 246 255


tabActiveTextLight : Color
tabActiveTextLight =
    rgb255 37 99 235


tabInactiveDark : Color
tabInactiveDark =
    rgb255 100 116 139


tabHoverBgDark : Color
tabHoverBgDark =
    rgb255 30 41 59


tabActiveBgDark : Color
tabActiveBgDark =
    rgb255 30 58 95


tabActiveTextDark : Color
tabActiveTextDark =
    rgb255 96 165 250



-- Theme-aware helpers


surfaceColor : Theme -> Color
surfaceColor theme =
    case theme of
        Light ->
            surfaceLight

        Dark ->
            surfaceDark


cardColor : Theme -> Color
cardColor theme =
    case theme of
        Light ->
            cardLight

        Dark ->
            cardDark


borderColor : Theme -> Color
borderColor theme =
    case theme of
        Light ->
            borderLight

        Dark ->
            borderDark


textColor : Theme -> Color
textColor theme =
    case theme of
        Light ->
            textLight

        Dark ->
            textDark


feedHeaderColor : Theme -> Color
feedHeaderColor theme =
    case theme of
        Light ->
            feedHeaderBgLight

        Dark ->
            feedHeaderBgDark


feedHeaderTextColor : Theme -> Color
feedHeaderTextColor theme =
    case theme of
        Light ->
            feedHeaderTextLight

        Dark ->
            feedHeaderTextDark


tabInactiveColor : Theme -> Color
tabInactiveColor theme =
    case theme of
        Light ->
            tabInactiveLight

        Dark ->
            tabInactiveDark


tabHoverBgColor : Theme -> Color
tabHoverBgColor theme =
    case theme of
        Light ->
            tabHoverBgLight

        Dark ->
            tabHoverBgDark


tabActiveBgColor : Theme -> Color
tabActiveBgColor theme =
    case theme of
        Light ->
            tabActiveBgLight

        Dark ->
            tabActiveBgDark


tabActiveTextColor : Theme -> Color
tabActiveTextColor theme =
    case theme of
        Light ->
            tabActiveTextLight

        Dark ->
            tabActiveTextDark



-- Scroll shadow gradient colors


scrollShadowLight : Color
scrollShadowLight =
    rgba255 0 0 0 0.2


scrollShadowDark : Color
scrollShadowDark =
    rgba255 0 0 0 0.6



-- Theme colors record for passing multiple colors at once


type alias ThemeColors =
    { background : Color
    , surface : Color
    , card : Color
    , border : Color
    , text : Color
    , feedHeaderBg : Color
    , feedHeaderText : Color
    , tabInactive : Color
    , tabHoverBg : Color
    , tabActiveBg : Color
    , tabActiveText : Color
    }



-- Get all theme colors at once


getThemeColors : Theme -> ThemeColors
getThemeColors theme =
    case theme of
        Light ->
            { background = surfaceLight
            , surface = surfaceLight
            , card = cardLight
            , border = borderLight
            , text = textLight
            , feedHeaderBg = feedHeaderBgLight
            , feedHeaderText = feedHeaderTextLight
            , tabInactive = tabInactiveLight
            , tabHoverBg = tabHoverBgLight
            , tabActiveBg = tabActiveBgLight
            , tabActiveText = tabActiveTextLight
            }

        Dark ->
            { background = surfaceDark
            , surface = surfaceDark
            , card = cardDark
            , border = borderDark
            , text = textDark
            , feedHeaderBg = feedHeaderBgDark
            , feedHeaderText = feedHeaderTextDark
            , tabInactive = tabInactiveDark
            , tabHoverBg = tabHoverBgDark
            , tabActiveBg = tabActiveBgDark
            , tabActiveText = tabActiveTextDark
            }
