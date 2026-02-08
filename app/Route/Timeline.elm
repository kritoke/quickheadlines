module Route.Timeline exposing (Model, Msg, init, subscriptions, update, view, backendTask)

{-| elm-pages Timeline page with SSR.
  
    This page prerenders the timeline from the server by calling
    backend API during build. The page re-uses the SPA logic
    from the existing SPA Timeline module.
-}

import Api exposing (TimelineResponse, TimelineItem)
import Element exposing (Element)
import Http
import Pages.Timeline as SPATimeline
import Shared exposing (Model)
import Task exposing (Task)


type alias Model = SPATimeline.Model


type Msg = SPATimeline.Msg


{-| elm-pages backendTask: fetch timeline during prerender.
  
    elm-pages will call this during build to get data for SSR.
    The task must produce (Model, Cmd Msg).
-}
backendTask : Task x ( Model, Cmd Msg )
backendTask =
    Http.toTask
        (Http.get
            { url = "/api/timeline?limit=100"
            , expect = Http.expectJson identity Api.timelineDecoder
            }
        )
        |> Task.map
            (\response ->
                let
                    ( newModel, cmd ) =
                        SPATimeline.init
                in
                ( { newModel | items = response.items }
                , cmd
                )
            )


init : ( Model, Cmd Msg )
init =
    SPATimeline.init


subscriptions : Model -> Sub Msg
subscriptions = SPATimeline.subscriptions


update : Msg -> Model -> ( Model, Cmd Msg )
update = SPATimeline.update


view : Shared.Model -> Model -> Element Msg
view = SPATimeline.view
