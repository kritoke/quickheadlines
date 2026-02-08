module TimelineTest exposing (..)

import Expect exposing (Expectation)
import Test exposing (Test, describe, test)
import Time exposing (Month(..), Posix, Zone)
import Pages.Timeline exposing (textColorFromBg, readableColorForTheme)
import Shared exposing (Theme(..))


suite : Test
suite =
    describe "Timeline color utilities"
        [ describe "textColorFromBg"
              [ test "returns dark text for light background" <|
                    \() ->
                        Expect.equal (textColorFromBg "rgb(255, 255, 255)") "rgb(31,41,35)"
              , test "returns light text for dark background" <|
                    \() ->
                        Expect.equal (textColorFromBg "rgb(0, 0, 0)") "rgb(255,255,255)"
              , test "returns dark text for mid-gray background" <|
                    \() ->
                        Expect.equal (textColorFromBg "rgb(128, 128, 128)") "rgb(31,41,35)"
              , test "returns light text for dark gray background" <|
                    \() ->
                        Expect.equal (textColorFromBg "rgb(50, 50, 50)") "rgb(255,255,255)"
              ]
        , describe "readableColorForTheme"
              [ test "prefers dark on light theme when high contrast" <|
                    \() ->
                        Expect.equal (readableColorForTheme "rgb(255, 255, 255)" Light) "rgb(31,41,35)"
              , test "prefers light on light theme when low contrast" <|
                    \() ->
                        Expect.equal (readableColorForTheme "rgb(200, 200, 200)" Light) "rgb(31,41,35)"
              , test "prefers light on dark theme when high contrast" <|
                    \() ->
                        Expect.equal (readableColorForTheme "rgb(0, 0, 0)" Dark) "rgb(255,255,255)"
              , test "prefers dark on dark theme when low contrast" <|
                    \() ->
                        Expect.equal (readableColorForTheme "rgb(30, 30, 30)") Dark) "rgb(31,41,35)"
              ]
        ]
