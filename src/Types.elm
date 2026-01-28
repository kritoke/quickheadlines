module Types exposing (..)

import Browser
import Browser.Navigation as Navigation
import AppEffect exposing (Effect)
import Http
import Json.Decode exposing (Decoder, bool, field, int, list, map, map3, nullable, string, succeed)
import Json.Decode.Pipeline exposing (optional, required)
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
    , now : Posix
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
    { tab : String
    , url : String
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
    , feedUrl : String
    , feedLink : String
    , favicon : String
    , faviconData : String
    , headerColor : Maybe String
    , clusterId : Maybe String
    , isRepresentative : Bool
    , clusterSize : Maybe Int
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
    | Tick Posix
    | -- Feeds page messages
      FeedsMsg FeedsMsg
    | -- Timeline page messages
      TimelineMsg TimelineMsg



-- Feeds Page Messages


type FeedsMsg
    = SwitchTab String
    | GotFeeds (Result Http.Error { tabs : List Tab, activeTab : String, feeds : List Feed })
    | LoadMore String Int
    | GotMoreItems String (Result Http.Error Feed)
    | UpdateAdaptiveColors



-- Timeline Page Messages


type TimelineMsg
    = LoadMoreTimeline
    | GotTimelineItems (Result Http.Error { items : List TimelineItem, hasMore : Bool, totalCount : Int })
    | ExpandCluster String
    | CollapseCluster String



-- Timeline Model Init and Update


initTimelineModel : () -> ( TimelineModel, Effect TimelineMsg )
initTimelineModel _ =
    ( { items = []
      , loading = True
      , hasMore = True
      , currentOffset = 0
      , expandedClusters = Set.empty
      }
    , AppEffect.sendCmd (getTimelineItems 100 0 GotTimelineItems)
    )


updateTimelineModel : TimelineMsg -> TimelineModel -> ( TimelineModel, Effect TimelineMsg )
updateTimelineModel msg model =
    case msg of
        LoadMoreTimeline ->
            if model.hasMore && not model.loading then
                ( { model | loading = True }
                , AppEffect.sendCmd (getTimelineItems 100 model.currentOffset GotTimelineItems)
                )

            else
                ( model, AppEffect.none )

        GotTimelineItems (Ok data) ->
            ( { model
                | items = model.items ++ data.items
                , loading = False
                , hasMore = data.hasMore
                , currentOffset = model.currentOffset + List.length data.items
              }
            , AppEffect.none
            )

        GotTimelineItems (Err _) ->
            ( { model | loading = False }
            , AppEffect.none
            )

        ExpandCluster clusterId ->
            ( { model | expandedClusters = Set.insert clusterId model.expandedClusters }
            , AppEffect.none
            )

        CollapseCluster clusterId ->
            ( { model | expandedClusters = Set.remove clusterId model.expandedClusters }
            , AppEffect.none
            )


getTimelineItems : Int -> Int -> (Result Http.Error { items : List TimelineItem, hasMore : Bool, totalCount : Int } -> TimelineMsg) -> Cmd TimelineMsg
getTimelineItems limit offset expectMsg =
    Http.get
        { url = "/api/timeline?limit=" ++ String.fromInt limit ++ "&offset=" ++ String.fromInt offset
        , expect = Http.expectJson expectMsg timelinePageDecoder
        }


timelinePageDecoder : Decoder { items : List TimelineItem, hasMore : Bool, totalCount : Int }
timelinePageDecoder =
    map3
        (\items hasMore totalCount -> { items = items, hasMore = hasMore, totalCount = totalCount })
        (field "items" (list timelineItemDecoder))
        (field "has_more" bool)
        (field "total_count" int)


timelineItemDecoder : Decoder TimelineItem
timelineItemDecoder =
    succeed TimelineItem
        |> required "id" string
        |> required "title" string
        |> required "link" string
        |> optional "pub_date" (nullable (map Time.millisToPosix int)) Nothing
        |> required "feed_title" string
        |> required "feed_url" string
        |> required "feed_link" string
        |> optional "favicon" string ""
        |> optional "favicon_data" string ""
        |> optional "header_color" (nullable string) Nothing
        |> optional "cluster_id" (nullable string) Nothing
        |> required "is_representative" bool
        |> optional "cluster_size" (nullable int) Nothing
