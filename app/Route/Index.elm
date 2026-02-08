module Route.Index exposing (Model, Msg, init, update, view, backendTask)

{-| elm-pages Index page with SSR.
  
    This page prerenders the home content from the server by calling
    backend API during build. The page re-uses the SPA logic
    from the existing SPA Home_ module.
-}

import Api exposing (FeedsResponse, Feed)
import Element exposing (Element)
import Http
import Pages.Home_ as SPAHome
import Shared exposing (Model)
import Task exposing (Task)


type alias Model = SPAHome.Model


type Msg = SPAHome.Msg


{-| elm-pages backendTask: fetch feeds during prerender.
  
    elm-pages will call this during build to get data for SSR.
    The task must produce (Model, Cmd Msg).
-}
backendTask : Task x ( Model, Cmd Msg )
backendTask =
    Http.toTask
        (Http.get
            { url = "/api/feeds"
            , expect = Http.expectJson identity Api.feedsDecoder
            }
        )
        |> Task.map
            (\response ->
                let
                    ( newModel, cmd ) =
                        SPAHome.init sharedModel
                in
                ( { newModel | feeds = response.feeds }
                , cmd
                )
            )


init : ( Model, Cmd Msg )
init =
    SPAHome.init sharedModel


update : Msg -> Model -> ( Model, Cmd Msg )
update = SPAHome.update


view : Shared.Model -> Model -> Element Msg
view = SPAHome.view


sharedModel : Shared.Model
sharedModel =
    Shared.init 1024 768 False (Time.millisToPosix 0) (Time.customZone -360 []) Nothing
