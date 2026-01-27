module Effect exposing (Effect, batch, gotTime, gotTimeZone, loadUrl, map, none, pushUrl, replaceUrl, sendCmd, sendMsg, toCmd)

import Browser.Navigation as Nav
import Http
import Task
import Time exposing (Posix, Zone)


type Effect msg
    = None
    | Batch (List (Effect msg))
    | SendCmd (Cmd msg)
    | SendMsg msg
    | PushUrl String
    | ReplaceUrl String
    | Back
    | LoadUrl String
    | GotTimeZone (Zone -> msg)
    | GotTime (Posix -> msg)


none : Effect msg
none =
    None


batch : List (Effect msg) -> Effect msg
batch =
    Batch


sendCmd : Cmd msg -> Effect msg
sendCmd =
    SendCmd


sendMsg : msg -> Effect msg
sendMsg =
    SendMsg


pushUrl : String -> Effect msg
pushUrl =
    PushUrl


replaceUrl : String -> Effect msg
replaceUrl =
    ReplaceUrl


back : Effect msg
back =
    Back


loadUrl : String -> Effect msg
loadUrl =
    LoadUrl


gotTimeZone : (Zone -> msg) -> Effect msg
gotTimeZone =
    GotTimeZone


gotTime : (Posix -> msg) -> Effect msg
gotTime =
    GotTime


map : (msg1 -> msg2) -> Effect msg1 -> Effect msg2
map fn effect =
    case effect of
        None ->
            None

        Batch effects ->
            Batch (List.map (map fn) effects)

        SendCmd cmd ->
            SendCmd (Cmd.map fn cmd)

        SendMsg msg ->
            SendMsg (fn msg)

        PushUrl url ->
            PushUrl url

        ReplaceUrl url ->
            ReplaceUrl url

        Back ->
            Back

        LoadUrl url ->
            LoadUrl url

        GotTimeZone tagger ->
            GotTimeZone (tagger >> fn)

        GotTime tagger ->
            GotTime (tagger >> fn)


toCmd : { key : Nav.Key } -> Effect msg -> Cmd msg
toCmd { key } effect =
    case effect of
        None ->
            Cmd.none

        Batch effects ->
            Cmd.batch (List.map (toCmd { key = key }) effects)

        SendCmd cmd ->
            cmd

        SendMsg msg ->
            Task.perform identity (Task.succeed msg)

        PushUrl url ->
            Nav.pushUrl key url

        ReplaceUrl url ->
            Nav.replaceUrl key url

        Back ->
            Nav.back key 1

        LoadUrl url ->
            Nav.load url

        GotTimeZone tagger ->
            Task.perform tagger Time.here

        GotTime tagger ->
            Task.perform tagger Time.now
