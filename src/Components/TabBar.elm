module Components.TabBar exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Theme exposing (ThemeColors, getThemeColors, tabActiveBgColor, tabActiveTextColor, tabHoverBgColor, tabInactiveColor)
import Types exposing (Tab, Theme(..))


view : Theme -> List Tab -> String -> (String -> msg) -> Element msg
view theme tabs activeTab onTabClick =
    row
        [ width fill
        , spacing 4
        , paddingXY 0 4
        , Border.widthEach { bottom = 1, top = 0, left = 0, right = 0 }
        , Element.paddingEach { top = 0, right = 0, bottom = 4, left = 0 }
        ]
        (List.map (tabButton theme activeTab onTabClick) tabs)


tabButton : Theme -> String -> (String -> msg) -> Tab -> Element msg
tabButton theme activeTab onTabClick tab =
    let
        isActive =
            tab.name == activeTab
    in
    el
        [ if isActive then
            Background.color (tabActiveBgColor theme)

          else
            Background.color (rgb255 0 0 0)
        , if isActive then
            Font.color (tabActiveTextColor theme)

          else
            Font.color (tabInactiveColor theme)
        , Border.rounded 6
        , paddingXY 8 6
        , Font.medium
        , Font.size 14
        , pointer
        , Events.onClick (onTabClick tab.name)
        , mouseOver
            [ if not isActive then
                Background.color (tabHoverBgColor theme)

              else
                Background.color (rgb255 0 0 0)
            ]
        ]
        (text tab.name)
