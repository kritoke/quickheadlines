module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Element exposing (Element, layout)
import Element.Background as Background
import Ports exposing (..)
import Theme exposing (..)
import Time exposing (Posix, Zone)
import Types exposing (..)
import Update exposing (update)
import Url exposing (Url)
import View exposing (view)



-- Main entry point


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = viewDocument
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- Flags from JavaScript


type alias Flags =
    { initialTheme : String
    , windowWidth : Int
    , windowHeight : Int
    }



-- Initialize the application


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        theme =
            case flags.initialTheme of
                "dark" ->
                    Dark

                _ ->
                    Light

        initialModel =
            { key = key
            , url = url
            , page = FeedsPage (initialFeedsModel (extractTabFromUrl url))
            , theme = theme
            , windowWidth = flags.windowWidth
            , windowHeight = flags.windowHeight
            , lastUpdated = Nothing
            , timeZone = Time.utc
            }

        initialCmds =
            [ getFeeds (extractTabFromUrl url)
            , getVersion
            ]
    in
    ( initialModel
    , Cmd.batch initialCmds
    )



-- View document wrapper


viewDocument : Model -> Browser.Document Msg
viewDocument model =
    { title = "QuickHeadlines"
    , body =
        [ layout
            [ Background.color (surfaceColor model.theme)
            , Font.color (textColor model.theme)
            ]
            (view model)
        ]
    }



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ themeChanged ThemeChanged
        , scrollEvent ScrollEvent
        , elementIntersected ElementIntersected
        , extractColor ExtractColor
        , windowResized WindowResized
        ]



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



-- Theme changed handler


themeChanged : (String -> msg) -> Sub msg
themeChanged toMsg =
    themeChanged toMsg



-- Scroll event handler


scrollEvent : ({ elementId : String, scrollTop : Int, scrollHeight : Int, clientHeight : Int } -> msg) -> Sub msg
scrollEvent toMsg =
    scrollEvent toMsg



-- Element intersected handler


elementIntersected : ({ elementId : String, isIntersecting : Bool } -> msg) -> Sub msg
elementIntersected toMsg =
    elementIntersected toMsg



-- Extract color handler


extractColor : ({ imageUrl : String, feedUrl : String } -> msg) -> Sub msg
extractColor toMsg =
    extractColor toMsg



-- Window resized handler


windowResized : ({ width : Int, height : Int } -> msg) -> Sub msg
windowResized toMsg =
    windowResized toMsg
