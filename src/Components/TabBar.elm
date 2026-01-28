module Components.TabBar exposing (view)

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Theme exposing (getThemeColors, tabActiveBgColor, tabActiveBgColorString, tabActiveTextColor, tabActiveTextColorString, tabHoverBgColor, tabHoverBgColorString, tabInactiveColor, tabInactiveColorString)
import Types exposing (Tab, Theme(..))


view : Theme -> List Tab -> String -> (String -> msg) -> Html msg
view theme tabs activeTab onTabClick =
    Html.div
        [ Html.Attributes.class "tab-container"
        ]
        (List.map (tabButton theme activeTab onTabClick) tabs)


tabButton : Theme -> String -> (String -> msg) -> Tab -> Html msg
tabButton theme activeTab onTabClick tab =
    let
        isActive =
            tab.name == activeTab

        bgColor =
            if isActive then
                tabActiveBgColorString theme
            else
                "transparent"

        textColor =
            if isActive then
                tabActiveTextColorString theme
            else
                tabInactiveColorString theme

        hoverBgColor =
            if not isActive then
                tabHoverBgColorString theme
            else
                "transparent"
    in
    Html.div
        [ Html.Attributes.class "tab-link"
        , if isActive then
            Html.Attributes.class "active"
          else
            Html.Attributes.classList []
        , Html.Attributes.style "background-color" bgColor
        , Html.Attributes.style "color" textColor
        , Html.Events.onClick (onTabClick tab.name)
        , Html.Attributes.style "cursor" "pointer"
        ]
        [ Html.text tab.name ]
