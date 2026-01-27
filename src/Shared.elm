module Shared exposing (Msg(..), Shared, init, subscriptions, update)

import Browser.Navigation as Nav
import Effect exposing (Effect)
import Time exposing (Posix, Zone)
import Types exposing (Theme(..))


type alias Shared =
    { key : Nav.Key
    , url : String
    , theme : Theme
    , windowWidth : Int
    , windowHeight : Int
    , lastUpdated : Maybe Posix
    , now : Posix
    , timeZone : Zone
    }


type Msg
    = ToggleTheme
    | WindowResized Int Int
    | TimeZoneChanged Zone
    | Tick Posix
    | GotLastUpdated Posix


init : String -> Nav.Key -> ( Shared, Effect Msg )
init url key =
    ( { key = key
      , url = url
      , theme = Light
      , windowWidth = 1024
      , windowHeight = 768
      , lastUpdated = Nothing
      , now = Time.millisToPosix 0
      , timeZone = Time.utc
      }
    , Effect.batch
        [ Effect.gotTimeZone TimeZoneChanged
        , Effect.gotTime Tick
        ]
    )


update : Msg -> Shared -> ( Shared, Effect Msg )
update msg shared =
    case msg of
        ToggleTheme ->
            ( { shared | theme = toggleTheme shared.theme }
            , Effect.none
            )

        WindowResized width height ->
            ( { shared | windowWidth = width, windowHeight = height }
            , Effect.none
            )

        TimeZoneChanged zone ->
            ( { shared | timeZone = zone }
            , Effect.none
            )

        Tick time ->
            ( { shared | now = time }
            , Effect.gotTime Tick
            )

        GotLastUpdated time ->
            ( { shared | lastUpdated = Just time }
            , Effect.none
            )


toggleTheme : Theme -> Theme
toggleTheme theme =
    case theme of
        Light ->
            Dark

        Dark ->
            Light


subscriptions : Shared -> Sub Msg
subscriptions _ =
    Sub.none
