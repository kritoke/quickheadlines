port module Application exposing (Flags, Model, Msg(..), Page(..), init, update, view)

import Browser
import Browser.Navigation as Nav
import Element exposing (Element, rgb255, text)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Layouts.Shared as Layout
import Pages.Home_ as Home
import Pages.Timeline as Timeline
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (lumeOrange, surfaceColor, textColor)
import Time
import Url


port saveTheme : String -> Cmd msg


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


type Msg
    = SharedMsg Shared.Msg
    | HomeMsg Home.Msg
    | TimelineMsg Timeline.Msg
    | NavigateTo Page
    | SwitchTab String
    | UrlChanged Url.Url


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        now =
            Time.millisToPosix 0

        zone =
            Time.utc

        shared =
            Shared.init flags.width flags.prefersDark now zone

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
                cmd =
                    case targetPage of
                        Home ->
                            Nav.pushUrl model.key "/"

                        Timeline ->
                            Nav.pushUrl model.key "/timeline"
            in
            ( { model | page = targetPage }
            , cmd
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
                    ( "Timeline - QuickHeadlines"
                    , Element.map TimelineMsg timelineContent
                    )
    in
    { title = title
    , body =
        [ Layout.layout
            { theme = theme
            , header = header
            , footer = text "© 2024 QuickHeadlines"
            , main = content
            }
            |> Element.layout []
        ]
    }


headerView : Model -> Element Msg
headerView model =
    let
        theme =
            model.shared.theme

        isMobile =
            model.shared.windowWidth < 768

        txtColor =
            textColor theme

        navBg =
            Theme.surfaceColor theme

        isActive pageName =
            case ( pageName, model.page ) of
                ( Home, Home ) ->
                    True

                ( Timeline, Timeline ) ->
                    True

                _ ->
                    False

        navButton pageName label =
            let
                active =
                    isActive pageName

                bg =
                    if active then
                        case theme of
                            Dark ->
                                rgb255 40 40 40

                            Light ->
                                rgb255 243 244 246

                    else
                        case theme of
                            Dark ->
                                rgb255 30 30 30

                            Light ->
                                rgb255 255 255 255

                color =
                    if active then
                        lumeOrange

                    else
                        case theme of
                            Dark ->
                                rgb255 148 163 184

                            Light ->
                                rgb255 75 85 99
            in
            Input.button
                [ Background.color bg
                , Font.color color
                , Font.size 14
                , Font.medium
                , Element.paddingXY 12 8
                , Border.rounded 6
                ]
                { onPress = Just (NavigateTo pageName)
                , label = text label
                }
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing 8
        ]
        [ Element.row
            [ Element.width Element.fill
            , Element.spacing 12
            ]
            [ Element.el
                [ Font.size (if isMobile then 18 else 28)
                , Font.bold
                , Font.color lumeOrange
                ]
                (text "QuickHeadlines")
            , if isMobile then
                Element.none

              else
                Element.row [ Element.spacing 8 ]
                    [ navButton Home "Home"
                    , navButton Timeline "Timeline"
                    ]
            , Element.el [ Element.alignRight ] (themeToggle model)
            ]
        , if isMobile then
            Element.row [ Element.spacing 8 ]
                [ navButton Home "Home"
                , navButton Timeline "Timeline"
                ]

          else
            Element.none
        ]


themeToggle : Model -> Element Msg
themeToggle model =
    let
        theme =
            model.shared.theme

        label =
            case model.shared.theme of
                Dark ->
                    "☀ Light"

                Light ->
                    "☾ Dark"

        bg =
            case theme of
                Dark ->
                    rgb255 40 40 40

                Light ->
                    rgb255 229 231 235
    in
    Input.button
        [ Background.color bg
        , Font.color lumeOrange
        , Font.size 14
        , Element.paddingXY 12 8
        , Border.rounded 6
        ]
        { onPress = Just (SharedMsg ToggleTheme)
        , label = Element.text label
        }
