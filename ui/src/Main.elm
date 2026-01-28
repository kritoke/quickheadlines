port module Main exposing (main)

import Application
import Browser
import Pages.Home_


port saveTheme : String -> Cmd msg


main : Program Application.Flags Application.Model Application.Msg
main =
    Browser.application
        { init = Application.init
        , view = Application.view
        , update = Application.update
        , subscriptions = subscriptions
        , onUrlChange = Application.UrlChanged
        , onUrlRequest = \_ -> Application.NavigateTo Application.Home
        }


subscriptions : Application.Model -> Sub Application.Msg
subscriptions model =
    Sub.none
