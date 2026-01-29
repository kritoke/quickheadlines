module Application exposing (Flags, Model, Msg(..), Page(..), init, update, view, subscriptions)

import Browser
import Browser.Navigation as Nav
import Element exposing (Element, rgb255, px, text)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Layouts.Shared as Layout
import Pages.Home_ as Home
import Pages.Timeline exposing (Msg(..))
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (lumeOrange, surfaceColor, textColor)
import Time
import Task
import Url


port saveTheme : String -> Cmd msg

port onNearBottom : (Bool -> msg) -> Sub msg


type alias Flags =
    { width : Int
    , height : Int
    , prefersDark : Bool
    }


type Page
    = Home
    | Timeline


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , page : Page
    , shared : Shared.Model
    , home : Home.Model
    , timeline : Timeline.Model
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        zone =
            Time.utc

        shared =
            Shared.init flags.width flags.height flags.prefersDark (Time.millisToPosix 0) zone

        ( homeModel, homeCmd ) =
            Home.init shared

        ( timelineModel, timelineCmd ) =
            Timeline.init shared

        page =
            if String.contains "/timeline" url.path then
                Timeline

            else
                Home
    in
    ( Model key url page shared homeModel timelineModel
    , Cmd.batch
        [ Cmd.map HomeMsg homeCmd
        , Cmd.map TimelineMsg timelineCmd
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SharedMsg sharedMsg ->
            let
                newShared =
                    Shared.update sharedMsg model.shared

                cmd =
                    case sharedMsg of
                        ToggleTheme ->
                            saveTheme (Shared.themeToString newShared.theme)

                        _ ->
                            Cmd.none
            in
            ( { model | shared = newShared }
            , cmd
            )

        HomeMsg homeMsg ->
            let
                ( newHomeModel, homeCmd ) =
                    Home.update model.shared homeMsg model.home
            in
            ( { model | home = newHomeModel }
            , Cmd.map HomeMsg homeCmd
            )

        TimelineMsg timelineMsg ->
            let
                ( newTimelineModel, timelineCmd ) =
                    Timeline.update model.shared timelineMsg model.timeline
            in
            ( { model | timeline = newTimelineModel }
            , Cmd.map TimelineMsg timelineCmd
            )

        NavigateTo targetPage ->
            let
                newPath =
                    case targetPage of
                        Home ->
                            "/"

                        Timeline ->
                            "/timeline"
                cmd =
                    Nav.pushUrl model.key newPath
            in
            ( { model | page = targetPage }
            , cmd
            )

        NavigateExternal href ->
            ( model
            , Nav.load href
            )

        SwitchTab tab ->
            let
                ( newHomeModel, homeCmd ) =
                    Home.update model.shared (Home.SwitchTab tab) model.home
            in
            ( { model | home = newHomeModel }
            , Cmd.map HomeMsg homeCmd
            )

        UrlChanged url ->
            let
                newPage =
                    if String.contains "/timeline" url.path then
                        Timeline

                    else
                        Home
            in
            ( { model | url = url, page = newPage }
            , Cmd.none
            )

        GotTime posix ->
            let
                shared =
                    model.shared

                newShared =
                    { shared | now = posix }
            in
            ( { model | shared = newShared }
            , Cmd.none
            )


view : Model -> Browser.Document Msg
view model =
    let
        shared =
            model.shared

        theme =
            shared.theme

        header =
            headerView model

        ( title, content ) =
            case model.page of
                Home ->
                    let
                        homeContent =
                            Home.view model.shared model.home
                    in
                    ( "QuickHeadlines"
                    , Element.map HomeMsg homeContent
                    )

                Timeline ->
                    let
                        timelineContent =
                            Timeline.view model.shared model.timeline
                    in
                    ( "Timeline"
                    , Element.map TimelineMsg timelineContent
                    )
    in
    { document
        = { title = title
        , body =
            Layout.layout
                { theme = theme
                , header = header
                , footer = footerView model.shared
                , main = mainView (title ++ " - QuickHeadlines")
                }
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.page of
        Timeline ->
            onNearBottom Timeline.NearBottom

        _ ->
            Sub.none


footerView : Model -> Element Msg
footerView model =
    row
        [ width fill
        , padding 16
        , spacing 8
        , Font.size 12
        , Font.color (rgb255 150 150 150)
        ]
        [ Element.none ]
