module Main exposing (main)

import Api exposing (getFeeds, getVersion)
import Browser
import Browser.Navigation as Nav
import Element exposing (layout, rgb255)
import Element.Background as Background
import Element.Font as Font
import Html
import Time exposing (Posix, Zone)
import Types exposing (FeedsModel, Model, Msg(..), Page(..), Theme(..), TimelineModel)
import Update exposing (update)
import Url exposing (Url)
import View exposing (view)



-- Main entry point


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = viewDocument
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- Initialize the application


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        theme =
            Light

        initialModel =
            { key = key
            , url = url
            , page = FeedsPage (initialFeedsModel (extractTabFromUrl url))
            , theme = theme
            , windowWidth = 1280
            , windowHeight = 720
            , lastUpdated = Nothing
            , timeZone = Time.utc
            }
    in
    ( initialModel
    , Cmd.batch
        [ getFeeds (extractTabFromUrl url)
        , getVersion
        ]
    )



-- View document wrapper


viewDocument : Model -> Browser.Document Msg
viewDocument model =
    let
        bgColor =
            if model.theme == Light then
                rgb255 249 250 251

            else
                rgb255 17 24 39

        textColor =
            if model.theme == Light then
                rgb255 30 41 59

            else
                rgb255 226 232 240
    in
    { title = "QuickHeadlines"
    , body =
        [ layout
            [ Background.color bgColor
            , Font.color textColor
            ]
            (view model)
        ]
    }



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- Extract tab from URL


extractTabFromUrl : Url -> String
extractTabFromUrl url =
    url.query
        |> Maybe.andThen (extractQueryParam "tab")
        |> Maybe.withDefault ""



-- Extract query parameter


extractQueryParam : String -> String -> Maybe String
extractQueryParam param queryString =
    queryString
        |> String.split "&"
        |> List.map (String.split "=")
        |> List.filterMap
            (\parts ->
                case parts of
                    [ key, value ] ->
                        if key == param then
                            Just value

                        else
                            Nothing

                    _ ->
                        Nothing
            )
        |> List.head



-- Initial feeds model


initialFeedsModel : String -> FeedsModel
initialFeedsModel activeTab =
    { activeTab = activeTab
    , tabs = []
    , feeds = []
    , loading = True
    , error = Nothing
    }
