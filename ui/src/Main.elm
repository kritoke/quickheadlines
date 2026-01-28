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
        , onUrlChange = \_ -> Application.HomeMsg (Pages.Home_.SwitchTab "all")
        , onUrlRequest = \_ -> Application.HomeMsg (Pages.Home_.SwitchTab "all")
        }


subscriptions : Application.Model -> Sub Application.Msg
subscriptions model =
    Sub.none
