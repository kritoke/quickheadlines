module Types exposing (..)

import Browser
import Browser.Navigation as Navigation
import Http
import Set exposing (Set)
import Time exposing (Posix, Zone)
import Url exposing (Url)



-- Main Application State


type alias Model =
    { key : Navigation.Key
    , url : Url
    , page : Page
    , theme : Theme
    , windowWidth : Int
    , windowHeight : Int
    , lastUpdated : Maybe Posix
    , timeZone : Zone
    }



-- Page Routing


type Page
    = FeedsPage FeedsModel
    | TimelinePage TimelineModel
    | NotFound



-- Feeds Page State


type alias FeedsModel =
    { activeTab : String
    , tabs : List Tab
    , feeds : List Feed
    , loading : Bool
    , error : Maybe String
    }



-- Timeline Page State


type alias TimelineModel =
    { items : List TimelineItem
    , loading : Bool
    , hasMore : Bool
    , currentOffset : Int
    , expandedClusters : Set String
    }



-- Theme


type Theme
    = Light
    | Dark



-- Feed Data


type alias Feed =
    { url : String
    , title : String
    , displayLink : String
    , siteLink : String
    , favicon : String
    , faviconData : String
    , headerColor : Maybe String
    , items : List FeedItem
    , totalItemCount : Int
    }



-- Feed Item


type alias FeedItem =
    { title : String
    , link : String
    , version : Maybe String
    , pubDate : Maybe Posix
    }



-- Tab


type alias Tab =
    { name : String
    }



-- Timeline Item


type alias TimelineItem =
    { id : String
    , title : String
    , link : String
    , pubDate : Maybe Posix
    , feedTitle : String
    , clusterId : Maybe String
    }



-- Messages


type Msg
    = UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | WindowResized Int Int
    | TimeZoneChanged Zone
    | ToggleTheme
    | GotLastUpdated (Result Http.Error Posix)
    | CheckForUpdates
    | -- Feeds page messages
      FeedsMsg FeedsMsg
    | -- Timeline page messages
      TimelineMsg TimelineMsg



-- Feeds Page Messages


type FeedsMsg
    = SwitchTab String
    | GotFeeds (Result Http.Error (List Feed))
    | LoadMore String Int
    | GotMoreItems String (Result Http.Error Feed)
    | UpdateAdaptiveColors



-- Timeline Page Messages


type TimelineMsg
    = LoadMoreTimeline
    | GotTimelineItems (Result Http.Error (List TimelineItem))
    | ExpandCluster String
    | CollapseCluster String
