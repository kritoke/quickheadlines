port module Main exposing (main)

import Application
import Browser
import Browser.Navigation as Nav
import Url


port saveTheme : String -> Cmd msg


main : Program Application.Flags Application.Model Application.Msg
main =
    Browser.application
        { init = Application.init
        , view = Application.view
        , update = Application.update
        , subscriptions = Application.subscriptions
        , onUrlChange = Application.UrlChanged
        , onUrlRequest = handleUrlRequest
        }


handleUrlRequest : Browser.UrlRequest -> Application.Msg
handleUrlRequest urlRequest =
    case urlRequest of
        Browser.Internal url ->
            Application.UrlChanged url

        Browser.External href ->
            Application.NavigateExternal href


subscriptions : Application.Model -> Sub Application.Msg
subscriptions model =
    Sub.none
