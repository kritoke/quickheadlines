module Shared exposing (Model, Msg(..), Theme(..), init, update, themeToString, getHeight)

import Time


type Theme
    = Dark
    | Light


type alias Model =
    { theme : Theme
    , windowWidth : Int
    , now : Time.Posix
    , zone : Time.Zone
    }


type Msg
    = ToggleTheme
    | WindowResized Int Int
    | SetTime Time.Posix


init : Int -> Bool -> Time.Posix -> Time.Zone -> Model
init width prefersDark now zone =
    { theme =
        if prefersDark then
            Dark

        else
            Light
    , windowWidth = width
    , now = now
    , zone = zone
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleTheme ->
            let
                newTheme =
                    case model.theme of
                        Dark ->
                            Light

                        Light ->
                            Dark
            in
            { model | theme = newTheme }

        WindowResized width _ ->
            { model | windowWidth = width }

        SetTime posix ->
            { model | now = posix }


getHeight : Time.Posix -> Maybe Int
getHeight _ =
    Nothing


themeToString : Theme -> String
themeToString theme =
    case theme of
        Dark ->
            "dark"

        Light ->
            "light"
