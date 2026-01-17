module Components.FeedBox exposing (view)

import Components.FeedBody as FeedBody
import Components.FeedHeader as FeedHeader
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Theme exposing (ThemeColors, cardColor, getThemeColors)
import Types exposing (Feed, Theme)


view : Int -> Theme -> Feed -> Element msg
view windowWidth theme feed =
    let
        boxHeight =
            feedBoxHeight windowWidth

        colors =
            getThemeColors theme
    in
    column
        [ width fill
        , height boxHeight
        , Border.rounded 12
        , Background.color (cardColor theme)
        , clip
        , pointer
        ]
        [ FeedHeader.view theme feed
        , FeedBody.view feed.items
        , if feed.totalItemCount >= 10 && feed.url /= "software://releases" then
            loadMoreButton feed.url feed.totalItemCount

          else
            Element.none
        ]


feedBoxHeight : Int -> Element.Length
feedBoxHeight windowWidth =
    if windowWidth >= 1024 then
        px 384

    else if windowWidth >= 768 then
        px 352

    else
        shrink


loadMoreButton : String -> Int -> Element msg
loadMoreButton url count =
    el
        [ centerX
        , padding 16
        ]
        (el
            [ Font.size 12
            , Font.medium
            , Font.color (rgb255 100 116 139)
            , Background.color (rgb255 241 245 249)
            , Border.rounded 6
            , pointer
            , mouseOver
                [ Background.color (rgb255 226 232 240)
                , Font.color (rgb255 30 41 59)
                ]
            ]
            (text "Load More")
        )
