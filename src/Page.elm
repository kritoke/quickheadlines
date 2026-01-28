module Page exposing (Page, new)

import AppEffect exposing (Effect)
import View exposing (View)


type Page model msg
    = Page
        { init : () -> ( model, Effect msg )
        , update : msg -> model -> ( model, Effect msg )
        , view : model -> View msg
        , subscriptions : model -> Sub msg
        }


new :
    { init : () -> ( model, Effect msg )
    , update : msg -> model -> ( model, Effect msg )
    , view : model -> View msg
    , subscriptions : model -> Sub msg
    }
    -> Page model msg
new config =
    Page config
