module Components.FeedHeader exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Image as Image
import Theme exposing (.., ThemeColors, getThemeColors, feedHeaderColor, feedHeaderTextColor)


view : Theme -> Feed -> Element msg
view theme feed =
    let
        colors =
            getThemeColors theme
    in
    row
        [ width fill
        , padding 12
        , Background.color (feedHeaderColor theme)
        , Border.rounded 12
        , spacing 12
        ]
        [ faviconView feed.favicon feed.faviconData
        , feedInfo theme feed
        ]


faviconView : String -> String -> Element msg
faviconView faviconUrl faviconData =
    el
        [ width (px 24)
        , height (px 24)
        ]
        (if faviconUrl /= "" then
            image [ width fill, height fill ]
                { src = faviconUrl
                , description = "Feed favicon"
                }

         else if faviconData /= "" then
            el
                [ width fill
                , height fill
                , Background.color (rgb255 200 200 200)
                , Border.rounded 4
                ]
                Element.none

         else
            el
                [ width fill
                , height fill
                , Background.color (rgb255 200 200 200)
                , Border.rounded 4
                ]
                Element.none
        )


feedInfo : Theme -> Feed -> Element msg
feedInfo theme feed =
    column
        [ width fill
        , spacing 2
        ]
        [ el
            [ Font.size 16
            , Font.bold
            , Font.color (feedHeaderTextColor theme)
            , Element.htmlAttribute (Element.Attribute "style" "word-wrap: break-word; line-height: 1.2;")
            ]
            (text feed.title)
        , if feed.displayLink /= "" then
            el
                [ Font.size 12
                , Font.color (feedHeaderTextColor theme)
                , Element.alpha 0.7
                ]
                (text feed.displayLink)

          else
            Element.none
        ]
