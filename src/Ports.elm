port module Ports exposing (..)

import Json.Decode exposing (Value)



-- Send theme to JavaScript


port setTheme : String -> Cmd msg



-- Receive theme from JavaScript


port themeChanged : (String -> msg) -> Sub msg



-- Initialize theme from cookie/storage


port initTheme : () -> Cmd msg



-- Send scroll position to JavaScript


port updateScrollShadow : { elementId : String, isAtBottom : Bool } -> Cmd msg



-- Receive scroll events from JavaScript


port scrollEvent : ({ elementId : String, scrollTop : Int, scrollHeight : Int, clientHeight : Int } -> msg) -> Sub msg



-- Request to observe element


port observeElement : String -> Cmd msg



-- Receive intersection events from JavaScript


port elementIntersected : ({ elementId : String, isIntersecting : Bool } -> msg) -> Sub msg



-- Request color extraction from image


port extractColor : { imageUrl : String, feedUrl : String } -> Cmd msg



-- Receive extracted color from JavaScript


port colorExtracted : ({ feedUrl : String, backgroundColor : String, textColor : String } -> msg) -> Sub msg



-- Window resize events


port windowResized : ({ width : Int, height : Int } -> msg) -> Sub msg
