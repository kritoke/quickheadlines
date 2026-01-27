module Components.FeedBox exposing (view)

import Components.FeedBody as FeedBody
import Components.FeedHeader as FeedHeader
import Html exposing (Html)
import Html.Attributes
import Theme exposing (cardColor, getThemeColors)
import Time exposing (Posix)
import Types exposing (Feed, Theme)


view : Int -> Posix -> Theme -> Feed -> Html msg
view windowWidth now theme feed =
    let
        boxHeight =
            feedBoxHeight windowWidth

        colors =
            getThemeColors theme
    in
    Html.div
        [ Html.Attributes.class "feed-box"
        , Html.Attributes.style "height" boxHeight
        , Html.Attributes.style "border-radius" "0.75rem"
        , Html.Attributes.style "background-color" (cardColor theme)
        , Html.Attributes.style "overflow" "hidden"
        , Html.Attributes.style "display" "flex"
        , Html.Attributes.style "flex-direction" "column"
        , Html.Attributes.style "align-items" "stretch"
        , Html.Attributes.style "width" "100%"
        ]
        [ FeedHeader.view theme feed
        , FeedBody.view now feed.items
        , if feed.totalItemCount >= 10 && feed.url /= "software://releases" then
            loadMoreButton feed.url feed.totalItemCount

          else
            Html.text ""
        ]


feedBoxHeight : Int -> String
feedBoxHeight windowWidth =
    if windowWidth >= 1024 then
        "24rem"

    else if windowWidth >= 768 then
        "22rem"

    else
        "auto"


loadMoreButton : String -> Int -> Html msg
loadMoreButton url count =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "justify-content" "center"
        , Html.Attributes.style "padding" "1rem"
        ]
        [ Html.div
            [ Html.Attributes.style "font-size" "0.75rem"
            , Html.Attributes.style "font-weight" "500"
            , Html.Attributes.style "color" "#64748b"
            , Html.Attributes.style "background-color" "#f1f5f9"
            , Html.Attributes.style "border-radius" "0.375rem"
            , Html.Attributes.style "padding" "0.5rem 0.75rem"
            , Html.Attributes.style "cursor" "pointer"
            ]
            [ Html.text "Load More" ]
        ]
