module Shared exposing (Model, Msg(..), Theme(..))

{-| Shared model and theme for elm-pages
  
    This module re-exports the original QuickHeadlines Shared module
    so elm-pages can use the actual QuickHeadlines theme and state
    management logic.
-}

import Element exposing (Element, centerX, centerY, rgb255)
import Element.Background as Background
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Json.Decode as Decode
import Json.Encode as Encode
import Theme exposing (cardColor, errorColor, mutedColor, surfaceColor, tabActiveBg, tabActiveText, tabInactiveText, tabHoverBg, textColor, themeToColors)


{-| Theme types and helpers
-}


type Theme
    = Light
    | Dark


type alias ThemeColors =
    { cardBg : Element.Color
    , cardText : Element.Color
    , cardMuted : Element.Color
    , surface : Element.Color
    , surfaceText : Element.Color
    , error : Element.Color
    , tabActiveBg : Element.Color
    , tabActiveText : Element.Color
    , tabInactiveText : Element.Color
    , tabHoverBg : Element.Color
    }


themeToColors : Theme -> ThemeColors
themeToColors theme =
    case theme of
        Light ->
            { cardBg = rgb255 255 254
            , cardText = rgb255 255 255
            , cardMuted = rgb255 255 255
            , surface = rgb255 255 254
            , surfaceText = rgb255 255 255
            , error = rgb255 100 100
            , tabActiveBg = rgb255 255 255
            , tabActiveText = rgb255 255 255
            , tabInactiveText = rgb255 100 100
            , tabHoverBg = rgb255 255 230
            }

        Dark ->
            { cardBg = rgb255 30 31 37
            , cardText = rgb255 255 255
            , cardMuted = rgb255 255 255
            , surface = rgb255 30 31 37
            , surfaceText = rgb255 255 255
            , error = rgb255 100 100
            , tabActiveBg = rgb255 40 40 40
            , tabActiveText = rgb255 255 255
            , tabInactiveText = rgb255 200 200 200
            , tabHoverBg = rgb255 70 70 70
            }


{-| Theme helpers
-}


cardColor : Theme -> Element.Color
cardColor theme =
    (themeToColors theme).cardBg


errorColor : Theme -> Element.Color
errorColor theme =
    (themeToColors theme).error


mutedColor : Theme -> Element.Color
mutedColor theme =
    (themeToColors theme).cardMuted


surfaceColor : Theme -> Element.Color
surfaceColor theme =
    (themeToColors theme).surface


textColor : Theme -> Element.Color
textColor theme =
    (themeToColors theme).surfaceText


tabActiveBg : Theme -> Element.Color
tabActiveBg theme =
    (themeToColors theme).tabActiveBg


tabActiveText : Theme -> Element.Color
tabActiveText theme =
    (themeToColors theme).tabActiveText


tabInactiveText : Theme -> Element.Color
tabInactiveText theme =
    (themeToColors theme).tabInactiveText


tabHoverBg : Theme -> Element.Color
tabHoverBg theme =
    (themeToColors theme).tabHoverBg


{-| Theme type conversion
-}


themeToString : Theme -> String
themeToString theme =
    case theme of
        Light ->
            "light"

        Dark ->
            "dark"


stringToTheme : String -> Theme
stringToTheme str =
    case str of
        "light" ->
            Light

        "dark" ->
            Dark


{-| Model and messages
-}


type alias Model =
    { windowWidth : Int
    , windowHeight : Int
    , prefersDark : Bool
    , theme : Theme
    }


type Msg
    = WindowResized Int Int
    | ToggleTheme
    | ThemeChanged Bool
    | SwitchTab String
    | NoOp


{-| Initialization
-}


init : Int -> Int -> Bool -> Model
init windowWidth windowHeight prefersDark =
    { windowWidth = windowWidth
    , windowHeight = windowHeight
    , prefersDark = prefersDark
    , theme =
            if prefersDark then
                Dark

            else
                Light
    }


{-| Update
-}


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WindowResized width height ->
            ( { model
                | windowWidth = width
                , windowHeight = height
                }
            , Cmd.none
            )

        ToggleTheme ->
            let
                newTheme =
                    if model.theme == Light then
                        Dark

                    else
                        Light
            in
            ( { model | theme = newTheme }
            , Cmd.none
            )

        ThemeChanged isDark ->
            ( { model | theme = if isDark then Dark else Light }
            , Cmd.none
            )

        SwitchTab _ ->
            ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


{-| Flags decoder for initial state
-}


flagsDecoder : Decode.Decoder Model
flagsDecoder =
    Decode.map3 init
        (Decode.field "width" Decode.int)
        (Decode.field "height" Decode.int)
        (Decode.field "prefersDark" Decode.bool)


{-| JSON encoding
-}


modelEncoder : Model -> Encode.Value
modelEncoder model =
    Encode.object
        [ ( "windowWidth", Encode.int model.windowWidth )
        , ( "windowHeight", Encode.int model.windowHeight )
        , ( "prefersDark", Encode.bool model.prefersDark )
        , ( "theme", Encode.string (themeToString model.theme) )
        ]
