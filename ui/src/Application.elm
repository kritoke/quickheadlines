port module Application exposing (Flags, Model, Msg(..), Page(..), init, update, view, subscriptions)

import Browser
import Browser.Navigation as Nav
import Element exposing (Element, rgb255, px, text, fill, width, height, spacing, padding, paddingXY, paddingEach, row, centerY, centerX, alignTop, alignRight, moveDown, htmlAttribute)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import Layouts.Shared as Layout
import Pages.Home_ as Home
import Pages.Timeline as Timeline
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (lumeOrange, surfaceColor, textColor)
import Time
import Task
import Url


port saveTheme : String -> Cmd msg

port saveCurrentPage : String -> Cmd msg

port onNearBottom : (Bool -> msg) -> Sub msg


type alias Flags =
    { width : Int
    , height : Int
    , prefersDark : Bool
    , timestamp : Int
    }


type Page
    = Home
    | Timeline


type Msg
    = SharedMsg Shared.Msg
    | HomeMsg Home.Msg
    | TimelineMsg Timeline.Msg
    | NavigateTo Page
    | NavigateExternal String
    | SwitchTab String
    | UrlChanged Url.Url
    | GotTime Time.Posix


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
            Shared.init flags.width flags.height flags.prefersDark (Time.millisToPosix (flags.timestamp * 1000)) zone

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
        [ Task.perform GotTime Time.now
        , Cmd.map HomeMsg homeCmd
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
            , saveCurrentPage url.path
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
     Browser.Document title
         [ Layout.layout { theme = theme, header = header, footer = footerView model.shared, main = content }
             |> Element.layout []
         ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- Update time every second for relative time display
          Time.every 1000 GotTime
        , case model.page of
            Timeline ->
                Sub.batch
                    [ Sub.map TimelineMsg (Timeline.subscriptions model.timeline)
                    , Sub.map TimelineMsg (onNearBottom Timeline.NearBottom)
                    ]

            _ ->
                Sub.none
        ]


footerView : Shared.Model -> Element Msg
footerView model =
    row
        [ width fill
        , padding 16
        , spacing 8
        , Font.size 12
        , Font.color (rgb255 150 150 150)
        ]
        [ Element.none ]


headerView : Model -> Element Msg
headerView model =
    let
        theme =
            model.shared.theme

        bg =
            surfaceColor theme

        txtColor =
            textColor theme

        border =
            Theme.borderColor theme

        -- Helper for active links
        navLink label target =
            let
                isActive =
                    model.page == target

                targetPath =
                    case target of
                        Home ->
                            "/"

                        Timeline ->
                            "/timeline"
            in
            Element.link
                [ Font.size 13
                , Font.bold
                , Font.color
                    (if isActive then
                        lumeOrange

                     else
                        txtColor
                    )
                , paddingXY 12 8
                , Border.widthEach { bottom = if isActive then 2 else 0, left = 0, right = 0, top = 0 }
                , Border.color lumeOrange
                , Element.mouseOver [ Font.color lumeOrange ]
                , centerY
                ]
                { url = targetPath
                , label = text label
                }
    in
    Element.row
        [ width fill
        , paddingEach { left = 20, right = 40, top = 4, bottom = 4 }
        , Background.color bg
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        , Border.color border
        , spacing 24
        ]
        [ -- Brand Section
          Element.link [ centerY ]
            { url = "/"
            , label =
                Element.row [ spacing 8 ]
                    [ Element.image
                        [ Element.width (px 16)
                        , Element.height (px 16)
                        , Border.rounded 2
                        ]
                        { src = "/logo.svg", description = "" }
                , Element.el
                    [ Font.size 16
                    , Font.bold
                    , Font.color txtColor
                    , Font.letterSpacing 0.5
                    , centerY
                    ]
                    (text "QUICKHEADLINES")
                    ]
            }
        , -- Navigation Section
          Element.row [ spacing 0, centerY, height fill ]
            [ navLink "HOME" Home
            , navLink "TIMELINE" Timeline
            ]
        , -- Actions Section
          Element.el [ alignRight, centerY ] (themeToggle model)
        ]


themeToggle : Model -> Element Msg
themeToggle model =
    let
        theme =
            model.shared.theme

        icon =
            case model.shared.theme of
                Shared.Dark ->
                    "☀"

                Shared.Light ->
                    "☾"

        label =
            case model.shared.theme of
                Shared.Dark ->
                    "Switch to Light"

                Shared.Light ->
                    "Switch to Dark"

        bg =
            case theme of
                Shared.Dark ->
                    rgb255 40 40 40

                Shared.Light ->
                    rgb255 229 231 235
    in
    Input.button
        [ Background.color bg
        , Font.color lumeOrange
        , Font.size 16
        , Element.paddingXY 10 8
        , Border.rounded 6
        , htmlAttribute (Html.Attributes.title label)
        ]
        { onPress = Just (SharedMsg ToggleTheme)
        , label = Element.text icon
        }


mainView : String -> Element Msg
mainView title =
    Element.el
        [ width fill
        , height fill
        ]
        (Element.text title)
