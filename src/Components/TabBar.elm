module Components.TabBar exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Theme exposing (ThemeColors, getThemeColors, tabActiveBgColor, tabActiveTextColor, tabHoverBgColor, tabInactiveColor)
import Types exposing (Tab, Theme(..))


view : Theme -> List Tab -> String -> Element msg
view theme tabs activeTab =
    row
        [ width fill
        , spacing 8
        , paddingXY 0 16
        ]
        (List.map (tabButton theme activeTab) tabs)


tabButton : Theme -> String -> Tab -> Element msg
tabButton theme activeTab tab =
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
        , paddingXY 16 8
        , Font.medium
        , pointer
        , mouseOver
            [ if not isActive then
                Background.color (tabHoverBgColor theme)

              else
                Background.color (rgb255 0 0 0)
            ]
        ]
        (text tab.name)
