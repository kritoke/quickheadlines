module Theme exposing
    ( Theme
    , ThemeColors
    , borderColor
    , cardColor
    , errorBgColor
    , errorBorderColor
    , errorTextColor
    , faviconPlaceholderColor
    , feedHeaderColor
    , feedHeaderTextColor
    , getThemeColors
    , loadMoreButtonColor
    , loadMoreButtonHoverColor
    , loadMoreButtonTextColor
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


errorBgLight : Color
errorBgLight =
    rgb255 254 242 242


errorBgDark : Color
errorBgDark =
    rgb255 127 29 29


errorBorderLight : Color
errorBorderLight =
    rgb255 220 38 38


errorBorderDark : Color
errorBorderDark =
    rgb255 239 68 68


errorTextLight : Color
errorTextLight =
    rgb255 127 29 29


errorTextDark : Color
errorTextDark =
    rgb255 254 202 202


loadMoreButtonLight : Color
loadMoreButtonLight =
    rgb255 241 245 249


loadMoreButtonDark : Color
loadMoreButtonDark =
    rgb255 55 65 81


loadMoreButtonHoverLight : Color
loadMoreButtonHoverLight =
    rgb255 226 232 240


loadMoreButtonHoverDark : Color
loadMoreButtonHoverDark =
    rgb255 75 85 99


loadMoreButtonTextLight : Color
loadMoreButtonTextLight =
    rgb255 100 116 139


loadMoreButtonTextDark : Color
loadMoreButtonTextDark =
    rgb255 203 213 225


faviconPlaceholderLight : Color
faviconPlaceholderLight =
    rgb255 200 200 200


faviconPlaceholderDark : Color
faviconPlaceholderDark =
    rgb255 75 85 99



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


errorBgColor : Theme -> Color
errorBgColor theme =
    case theme of
        Light ->
            errorBgLight

        Dark ->
            errorBgDark


errorBorderColor : Theme -> Color
errorBorderColor theme =
    case theme of
        Light ->
            errorBorderLight

        Dark ->
            errorBorderDark


errorTextColor : Theme -> Color
errorTextColor theme =
    case theme of
        Light ->
            errorTextLight

        Dark ->
            errorTextDark


loadMoreButtonColor : Theme -> Color
loadMoreButtonColor theme =
    case theme of
        Light ->
            loadMoreButtonLight

        Dark ->
            loadMoreButtonDark


loadMoreButtonHoverColor : Theme -> Color
loadMoreButtonHoverColor theme =
    case theme of
        Light ->
            loadMoreButtonHoverLight

        Dark ->
            loadMoreButtonHoverDark


loadMoreButtonTextColor : Theme -> Color
loadMoreButtonTextColor theme =
    case theme of
        Light ->
            loadMoreButtonTextLight

        Dark ->
            loadMoreButtonTextDark


faviconPlaceholderColor : Theme -> Color
faviconPlaceholderColor theme =
    case theme of
        Light ->
            faviconPlaceholderLight

        Dark ->
            faviconPlaceholderDark



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
    , errorBg : Color
    , errorBorder : Color
    , errorText : Color
    , loadMoreButton : Color
    , loadMoreButtonHover : Color
    , loadMoreButtonText : Color
    , faviconPlaceholder : Color
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
            , errorBg = errorBgLight
            , errorBorder = errorBorderLight
            , errorText = errorTextLight
            , loadMoreButton = loadMoreButtonLight
            , loadMoreButtonHover = loadMoreButtonHoverLight
            , loadMoreButtonText = loadMoreButtonTextLight
            , faviconPlaceholder = faviconPlaceholderLight
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
            , errorBg = errorBgDark
            , errorBorder = errorBorderDark
            , errorText = errorTextDark
            , loadMoreButton = loadMoreButtonDark
            , loadMoreButtonHover = loadMoreButtonHoverDark
            , loadMoreButtonText = loadMoreButtonTextDark
            , faviconPlaceholder = faviconPlaceholderDark
            }
