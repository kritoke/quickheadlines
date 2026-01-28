module Components.FeedHeader exposing (view)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Theme exposing (faviconPlaceholderColor)
import Types exposing (Feed)


view : Feed -> Element msg
view feed =
    let
        headerBg =
            case feed.headerColor of
                Just colorStr ->
                    -- Use the color from color thief
                    let
                        hexToRgb color =
                            -- Parse hex color like "#3b82f6" or "3b82f6"
                            let
                                cleanHex =
                                    if String.startsWith "#" color then
                                        String.dropLeft 1 color

                                    else
                                        color

                                r =
                                    String.slice 0 2 cleanHex |> String.toIntMaybe |> Maybe.withDefault 243

                                g =
                                    String.slice 2 4 cleanHex |> String.toIntMaybe |> Maybe.withDefault 244

                                b =
                                    String.slice 4 6 cleanHex |> String.toIntMaybe |> Maybe.withDefault 246
                            in
                            rgb255 r g b
                    in
                    Background.color (hexToRgb colorStr)

                Nothing ->
                    Background.color (rgb255 243 244 246)
    in
    row
        [ padding 8
        , paddingXY 12 8
        , headerBg
        , Border.rounded 12
        , spacing 12
        , width fill
        ]
        [ faviconView feed.favicon feed.faviconData
        , feedInfo feed
        ]


faviconView : String -> String -> Element msg
faviconView faviconUrl faviconData =
    if faviconUrl /= "" then
        image
            [ width (px 24)
            , height (px 24)
            , Border.rounded 4
            ]
            { src = faviconUrl, description = "Feed favicon" }

    else
        el
            [ width (px 24)
            , height (px 24)
            , Background.color (rgb255 200 200 200)
            , Border.rounded 4
            ]
            none


feedInfo : Feed -> Element msg
feedInfo feed =
    column
        [ spacing 2
        , width fill
        ]
        [ link
            [ Font.size 18
            , Font.bold
            , Font.color (rgb255 31 41 55)
            , Font.underline
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            ]
            { url = feed.siteLink, label = text feed.title }
        , if feed.displayLink /= "" then
            el
                [ Font.size 12
                , Font.color (rgb255 107 114 128)
                , alpha 0.8
                ]
                (text feed.displayLink)

          else
            none
        ]
