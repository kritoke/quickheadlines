port module Application exposing (Flags, Model, Msg(..), Page(..), init, update, view, subscriptions)

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element exposing (Element, rgb255, px, text, fill, width, height, spacing, padding, paddingXY, paddingEach, row, centerY, centerX, alignTop, alignRight, moveDown, htmlAttribute, el, clip)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import Html.Attributes as HA
import Layouts.Shared as Layout
import Pages.Home_ as Home
import Pages.Timeline as Timeline
import Responsive exposing (Breakpoint(..), breakpointFromWidth)
import Shared exposing (Model, Msg(..), Theme(..))
import Theme exposing (lumeOrange, surfaceColor, textColor)
import ThemeTypography as Ty
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
          [ Layout.layout { theme = theme, windowWidth = model.shared.windowWidth, header = header, footer = footerView model.shared, main = content }
             |> Element.layout []
         ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- Update time every second for relative time display
          Time.every 1000 GotTime
        , -- Listen for window resize events
          Browser.Events.onResize (\w h -> SharedMsg (Shared.WindowResized w h))
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

        breakpoint =
            Responsive.breakpointFromWidth model.shared.windowWidth

        headerPadding =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    { left = 8, right = 8, top = 4, bottom = 4 }

                MobileBreakpoint ->
                    { left = 12, right = 12, top = 4, bottom = 4 }

                TabletBreakpoint ->
                    { left = 24, right = 24, top = 8, bottom = 8 }

                DesktopBreakpoint ->
                    { left = 40, right = 40, top = 8, bottom = 8 }

        -- Helper for active link icons
        navLink iconPath target =
            let
                isActive =
                    model.page == target

                targetPath =
                    case target of
                        Home ->
                            "/"

                        Timeline ->
                            "/timeline"

                iconHtml =
                    Html.img
                        [ HA.src iconPath
                        , HA.style "width" "24px"
                        , HA.style "height" "24px"
                        ]
                        []
            in
            Element.el
                [ Element.padding 8
                , Border.widthEach { bottom = if isActive then 2 else 0, left = 0, right = 0, top = 0 }
                , Border.color lumeOrange
                , Element.mouseOver [ Font.color lumeOrange ]
                , centerY
                , htmlAttribute (HA.style "display" "flex")
                , htmlAttribute (HA.style "align-items" "center")
                , htmlAttribute (HA.style "justify-content" "center")
                ]
                (Element.link []
                    { url = targetPath
                    , label = el [ htmlAttribute (HA.style "display" "flex") ] (Element.html iconHtml)
                    }
                )

        -- Active icon style - brighter version for active state
        activeIconStyle =
            [ Font.color lumeOrange
            , Border.widthEach { bottom = 2, left = 0, right = 0, top = 0 }
            , Border.color lumeOrange
            ]
    in
    Element.row
        [ width fill
        , paddingEach headerPadding
        , Background.color bg
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        , Border.color border
        , spacing 12
        ]
        [ -- Brand Section
          Element.link [ centerY ]
            { url = "/"
            , label =
                Element.row [ spacing 10, centerY ]
                    [ Element.image
                        [ Element.width (px 32)
                        , Element.height (px 32)
                        , Border.rounded 4
                        ]
                        { src = "/logo.svg", description = "Logo" }
                    , Element.el
                        [ Ty.subtitle
                        , Font.bold
                        , Font.color txtColor
                        , Font.letterSpacing 0.5
                        , centerY
                        ]
                        (text "Quick Headlines")
                    ]
             }
        , -- Navigation Section
          Element.row [ spacing 4, centerY, height fill ]
            [ homeIconView model Home
            , timelineIconView model Timeline
            ]
        , -- Actions Section
          Element.el [ alignRight, centerY ] (themeToggle model)
        ]


homeIconView : Model -> Page -> Element Msg
homeIconView model target =
    let
        isActive =
            model.page == Home

        iconPath =
            if isActive then "/home-icon-active.svg" else "/home-icon.svg"

        iconHtml =
            Html.img
                [ HA.src iconPath
                , HA.style "width" "28px"
                , HA.style "height" "28px"
                ]
                []
    in
    Element.el
        [ Element.padding 10
        , Border.widthEach { bottom = if isActive then 2 else 0, left = 0, right = 0, top = 0 }
        , Border.color lumeOrange
        , Element.mouseOver [ Font.color lumeOrange ]
        , centerY
        , htmlAttribute (HA.style "display" "flex")
        , htmlAttribute (HA.style "align-items" "center")
        , htmlAttribute (HA.style "justify-content" "center")
        ]
        (Element.link []
            { url = "/"
            , label = el [ htmlAttribute (HA.style "display" "flex") ] (Element.html iconHtml)
            }
        )


timelineIconView : Model -> Page -> Element Msg
timelineIconView model target =
    let
        isActive =
            model.page == Timeline

        iconPath =
            if isActive then "/timeline-icon-active.svg" else "/timeline-icon.svg"

        iconHtml =
            Html.img
                [ HA.src iconPath
                , HA.style "width" "28px"
                , HA.style "height" "28px"
                ]
                []
    in
    Element.el
        [ Element.padding 10
        , Border.widthEach { bottom = if isActive then 2 else 0, left = 0, right = 0, top = 0 }
        , Border.color lumeOrange
        , Element.mouseOver [ Font.color lumeOrange ]
        , centerY
        , htmlAttribute (HA.style "display" "flex")
        , htmlAttribute (HA.style "align-items" "center")
        , htmlAttribute (HA.style "justify-content" "center")
        ]
        (Element.link []
            { url = "/timeline"
            , label = el [ htmlAttribute (HA.style "display" "flex") ] (Element.html iconHtml)
            }
        )


themeToggle : Model -> Element Msg
themeToggle model =
    let
        theme =
            model.shared.theme

        breakpoint =
            Responsive.breakpointFromWidth model.shared.windowWidth

        iconPadding =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    4

                MobileBreakpoint ->
                    6

                _ ->
                    10

        bg =
            case theme of
                Shared.Dark ->
                    rgb255 40 40 40

                Shared.Light ->
                    rgb255 229 231 235

        label =
            case theme of
                Shared.Dark ->
                    "Switch to Light"

                Shared.Light ->
                    "Switch to Dark"

        iconHtml =
            case theme of
                Shared.Dark ->
                    Html.img
                        [ HA.src "/sun-icon.svg"
                        , HA.style "width" "20px"
                        , HA.style "height" "20px"
                        ]
                        []

                Shared.Light ->
                    Html.img
                        [ HA.src "/moon-icon.svg"
                        , HA.style "width" "20px"
                        , HA.style "height" "20px"
                        ]
                        []
    in
    Input.button
        [ Background.color bg
        , Element.padding iconPadding
        , Border.rounded 6
        , htmlAttribute (HA.title label)
        , htmlAttribute (HA.style "display" "flex")
        , htmlAttribute (HA.style "align-items" "center")
        , htmlAttribute (HA.style "justify-content" "center")
        , htmlAttribute (HA.style "min-width" "36px")
        , htmlAttribute (HA.style "min-height" "36px")
        ]
        { onPress = Just (SharedMsg ToggleTheme)
        , label = el [ centerX, centerY, htmlAttribute (HA.style "display" "flex") ] (Element.html iconHtml)
        }


mainView : String -> Element Msg
mainView title =
    Element.el
        [ width fill
        , height fill
        ]
        (Element.text title)
