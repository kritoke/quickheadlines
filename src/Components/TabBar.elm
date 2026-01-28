module Components.TabBar exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes
import Theme exposing (borderColor, tabActiveBgColor, tabActiveTextColor, tabHoverBgColor, tabInactiveColor)
import Types exposing (Tab, Theme(..))


view : Theme -> List Tab -> String -> (String -> msg) -> Element msg
view theme tabs activeTab onTabClick =
    wrappedRow
        [ width fill
        , spacing 8
        , paddingEach { top = 0, right = 0, bottom = 8, left = 0 }
        , Border.widthEach { top = 0, right = 0, bottom = 1, left = 0 }
        , Border.color (borderColor theme)
        ]
        (List.map (tabButton theme activeTab onTabClick) tabs)


tabButton : Theme -> String -> (String -> msg) -> Tab -> Element msg
tabButton theme activeTab onTabClick tab =
    let
        isActive =
            tab.name == activeTab

        bgColor =
            if isActive then
                tabActiveBgColor theme

            else
                tabHoverBgColor theme

        textColorVal =
            if isActive then
                tabActiveTextColor theme

            else
                tabInactiveColor theme
    in
    if isActive then
        el
            [ paddingXY 12 6
            , Border.rounded 6
            , Font.size 13
            , Font.medium
            , Font.color textColorVal
            , Background.color bgColor
            , htmlAttribute (Html.Attributes.class "tab-link active")
            ]
            (text tab.name)

    else
        Input.button
            [ paddingXY 12 6
            , Border.rounded 6
            , Font.size 13
            , Font.medium
            , Font.color textColorVal
            , Background.color bgColor
            , pointer
            , htmlAttribute (Html.Attributes.class "tab-link")
            ]
            { onPress = Just (onTabClick tab.name)
            , label = text tab.name
            }
