module Components.FeedHeader exposing (view)

import Html exposing (Html)
import Html.Attributes
import Theme exposing (feedHeaderColor, feedHeaderColorString, feedHeaderTextColor, feedHeaderTextColorString, getThemeColors)
import Types exposing (Feed, Theme(..))


view : Theme -> Feed -> Html msg
view theme feed =
    let
        colors =
            getThemeColors theme
    in
    Html.div
        [ Html.Attributes.class "feed-header"
        , Html.Attributes.style "padding" "0.5rem 0.75rem"
        , Html.Attributes.style "background-color" (feedHeaderColorString theme)
        , Html.Attributes.style "border-radius" "0.75rem"
        , Html.Attributes.style "margin-bottom" "0.4rem"
        , Html.Attributes.style "flex" "0 0 auto"
        , Html.Attributes.style "display" "flex"
        , Html.Attributes.style "gap" "0.75rem"
        , Html.Attributes.style "width" "100%"
        ]
        [ faviconView feed.favicon feed.faviconData
        , feedInfo theme feed
        ]


faviconView : String -> String -> Html msg
faviconView faviconUrl faviconData =
    Html.div
        [ Html.Attributes.style "width" "24px"
        , Html.Attributes.style "height" "24px"
        , Html.Attributes.style "flex-shrink" "0"
        ]
        [ if faviconUrl /= "" then
            Html.img
                [ Html.Attributes.src faviconUrl
                , Html.Attributes.alt "Feed favicon"
                , Html.Attributes.style "width" "100%"
                , Html.Attributes.style "height" "100%"
                ]
                []

          else
            Html.div
                [ Html.Attributes.style "width" "100%"
                , Html.Attributes.style "height" "100%"
                , Html.Attributes.style "background-color" "#c8c8c8"
                , Html.Attributes.style "border-radius" "0.25rem"
                ]
                []
        ]


feedInfo : Theme -> Feed -> Html msg
feedInfo theme feed =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "flex-direction" "column"
        , Html.Attributes.style "gap" "0.125rem"
        , Html.Attributes.style "width" "100%"
        ]
        [ Html.a
            [ Html.Attributes.href feed.siteLink
            , Html.Attributes.class "feed-title-link"
            , Html.Attributes.style "font-size" "1.1rem"
            , Html.Attributes.style "font-weight" "700"
            , Html.Attributes.style "color" (feedHeaderTextColorString theme)
            , Html.Attributes.style "line-height" "1.2"
            , Html.Attributes.style "word-wrap" "break-word"
            , Html.Attributes.style "text-decoration" "underline"
            ]
            [ Html.text feed.title ]
        , if feed.displayLink /= "" then
            Html.span
                [ Html.Attributes.style "font-size" "0.75rem"
                , Html.Attributes.style "color" (feedHeaderTextColorString theme)
                , Html.Attributes.style "opacity" "0.7"
                ]
                [ Html.text feed.displayLink ]

          else
            Html.text ""
        ]
