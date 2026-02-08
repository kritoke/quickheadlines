port module Application exposing (Flags, Model, Msg(..), Page(..), init, update, view, subscriptions)

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element exposing (Element, rgb255, rgba, px, text, fill, width, height, spacing, padding, paddingXY, paddingEach, row, centerY, centerX, alignTop, alignRight, moveDown, htmlAttribute, el, clip)
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
import Theme exposing (headerSurface, lumeOrange, surfaceColor, textColor)
import ThemeTypography as Ty
import Time
import Task
import Url


port saveTheme : String -> Cmd msg


port saveCurrentPage : String -> Cmd msg


port saveTimelineState : String -> Cmd msg


port saveActiveTab : String -> Cmd msg


port onNearBottom : (Bool -> msg) -> Sub msg

port switchTab : (String -> msg) -> Sub msg

port envThemeChanged : (Bool -> msg) -> Sub msg


type alias Flags =
    { width : Int
    , height : Int
    , prefersDark : Bool
    , timestamp : Int
    , savedTab : Maybe String
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
            Time.customZone -360 []

        shared =
            Shared.init flags.width flags.height flags.prefersDark (Time.millisToPosix (flags.timestamp * 1000)) zone flags.savedTab

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

        isTimeline =
            case model.page of
                Timeline -> True
                _ -> False

        pageDataAttr =
            if isTimeline then
                htmlAttribute (HA.attribute "data-timeline-page" "true")
            else
                htmlAttribute (HA.attribute "data-page" "home")

        layoutContent =
            Layout.layout { theme = theme, windowWidth = model.shared.windowWidth, header = header, footer = footerView model.shared, main = content, isTimeline = isTimeline }
    in
    Browser.Document title
        [ Element.layout [ pageDataAttr ] layoutContent
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- Update time every second for relative time display
          Time.every 1000 GotTime
        , -- Listen for window resize events
          Browser.Events.onResize (\w h -> SharedMsg (Shared.WindowResized w h))
        , -- Listen for tab switch from JavaScript
          switchTab SwitchTab
        , -- Listen for OS theme changes from JavaScript
          envThemeChanged (\isDark -> SharedMsg (Shared.SetSystemTheme isDark))
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
            Theme.headerSurface theme

        txtColor =
            textColor theme

        border =
            Theme.borderColor theme

        breakpoint =
            Responsive.breakpointFromWidth model.shared.windowWidth

        brandLabel =
            case breakpoint of
                VeryNarrowBreakpoint ->
                    Element.none

                MobileBreakpoint ->
                    Element.none

                _ ->
                    Element.el
                        (Ty.hero breakpoint
                            ++ [ Font.color txtColor
                               , centerY
                               , paddingEach { top = 0, bottom = 0, left = 6, right = 6 }
                               ]
                        )
                        (text "Quick Headlines")
    in
    Element.row
        [ width fill
        , Background.color bg
        , spacing 12
        , htmlAttribute (HA.style "flex-wrap" "nowrap")
        , htmlAttribute (HA.style "overflow-x" "hidden")
        , htmlAttribute (HA.style "justify-content" "space-between")
        , htmlAttribute (HA.style "backdrop-filter" "blur(6px)")
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        , Border.color
            (case theme of
                Shared.Dark ->
                    rgba 1 1 1 0.06

                Shared.Light ->
                    rgba 15 23 42 0.06
            )
        , htmlAttribute (HA.class "qh-site-header")
        ]
        [ -- Brand Section
          Element.link [ centerY, paddingEach { top = 0, bottom = 0, left = 6, right = 6 } ]
            { url = "/"
            , label =
                Element.row [ spacing 10, centerY ]
                    [ Element.image
                        [ Element.width (px 32)
                        , Element.height (px 32)
                        , Border.rounded 8
                        ]
                        { src = "/logo.svg", description = "Logo" }
                    , brandLabel
                    ]
             }
        , -- Navigation Section
          Element.row [ spacing 4, centerY, height fill ]
            [ homeIconView model Home
            , timelineIconView model Timeline
            ]
        , -- Actions Section
          Element.el [ alignRight, centerY, paddingEach { top = 0, bottom = 0, left = 0, right = 8 } ] (themeToggle model)
        ]


homeIconView : Model -> Page -> Element Msg
homeIconView model target =
    let
        isActive =
            model.page == Home

        iconPath =
            "/home-icon.svg"

        iconHtml =
            Html.img
                [ HA.src iconPath
                , HA.style "width" "28px"
                , HA.style "height" "28px"
                ]
                []

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
    in
    Element.el
        [ Element.padding iconPadding
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
            "/timeline-icon.svg"

        iconHtml =
            Html.img
                [ HA.src iconPath
                , HA.style "width" "28px"
                , HA.style "height" "28px"
                ]
                []

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
    in
    Element.el
        [ Element.padding iconPadding
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
                        , HA.style "width" "28px"
                        , HA.style "height" "28px"
                        ]
                        []

                Shared.Light ->
                    Html.img
                        [ HA.src "/moon-icon.svg"
                        , HA.style "width" "28px"
                        , HA.style "height" "28px"
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
