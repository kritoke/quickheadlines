module Shared exposing (Msg(..), Shared, Size, init, subscriptions, update)

import Browser.Navigation as Nav
import AppEffect exposing (Effect(..))
import Task
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
    | WindowResized Size
    | TimeZoneChanged Zone
    | Tick Posix
    | GotLastUpdated Posix


type alias Size =
    { width : Int, height : Int }


init : String -> Nav.Key -> Int -> Int -> Types.Theme -> ( Shared, Effect Msg )
init url key width height initialTheme =
    ( { key = key
      , url = url
      , theme = initialTheme
      , windowWidth = width
      , windowHeight = height
      , lastUpdated = Nothing
      , now = Time.millisToPosix 0
      , timeZone = Time.utc
      }
    , AppEffect.sendCmd (Task.perform (gotTime >> mapToTick) Time.now)
    )


gotTime : Posix -> Posix
gotTime time =
    time


mapToTick : Posix -> Msg
mapToTick time =
    Tick time


update : Msg -> Shared -> ( Shared, Effect Msg )
update msg shared =
    case msg of
        ToggleTheme ->
            ( { shared | theme = toggleTheme shared.theme }
            , AppEffect.none
            )

        WindowResized { width, height } ->
            ( { shared | windowWidth = width, windowHeight = height }
            , AppEffect.none
            )

        TimeZoneChanged zone ->
            ( { shared | timeZone = zone }
            , AppEffect.none
            )

        Tick time ->
            ( { shared | now = time }
            , AppEffect.none
            )

        GotLastUpdated time ->
            ( { shared | lastUpdated = Just time }
            , AppEffect.none
            )


toggleTheme : Theme -> Theme
toggleTheme theme =
    case theme of
        Light ->
            Dark

        Dark ->
            Light


subscriptions : Shared -> Sub Msg
subscriptions shared =
    Time.every 60000 (Tick)
