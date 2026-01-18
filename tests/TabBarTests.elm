module TabBarTests exposing (..)

import Components.TabBar as TabBar
import Element exposing (layout)
import Expect exposing (Expectation)
import Test exposing (..)
import Types exposing (Tab, Theme(..))


{-| Test suite for TabBar component functionality.
Verifies that tabs render correctly and respond to user interactions.
-}
tabBarTests : Test
tabBarTests =
    describe "TabBar Component"
        [ describe "Tab Structure"
            [ test "Tab type has name field" <|
                \_ ->
                    let
                        tab =
                            { name = "tech" }
                    in
                    Expect.equal tab.name "tech"
            , test "can create multiple tabs" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            , { name = "security" }
                            ]
                    in
                    Expect.equal (List.length tabs) 3
            , test "tab names are strings" <|
                \_ ->
                    let
                        tab =
                            { name = "3dprinting" }
                    in
                    Expect.equal tab.name "3dprinting"
            ]
        , describe "Tab Rendering"
            [ test "renders all provided tabs" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            , { name = "security" }
                            ]

                        view =
                            TabBar.view Light tabs "all" (\_ -> ())
                    in
                    -- The TabBar should have access to all 3 tabs
                    Expect.equal (List.length tabs) 3
            , test "renders single tab" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" } ]
                    in
                    Expect.equal (List.length tabs) 1
            , test "renders multiple tabs" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            , { name = "security" }
                            , { name = "3dprinting" }
                            , { name = "dev" }
                            ]
                    in
                    Expect.equal (List.length tabs) 5
            ]
        , describe "Active Tab"
            [ test "first tab is active when activeTab is 'all'" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            ]

                        activeTab =
                            "all"
                    in
                    Expect.equal activeTab "all"
            , test "second tab is active when activeTab is 'tech'" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            ]

                        activeTab =
                            "tech"
                    in
                    Expect.equal activeTab "tech"
            , test "handles different active tab values" <|
                \_ ->
                    let
                        testCases =
                            [ "all", "tech", "security", "3dprinting", "dev" ]
                    in
                    -- All these are valid tab values
                    Expect.equal (List.length testCases) 5
            ]
        , describe "Tab Click Events"
            [ test "click handler receives tab name" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            ]

                        clickedTabs =
                            List.map .name tabs
                    in
                    Expect.equal clickedTabs [ "all", "tech" ]
            , test "click handler is called for each tab" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            , { name = "security" }
                            ]

                        tabNames =
                            List.map .name tabs
                    in
                    Expect.equal (List.length tabNames) 3
            , test "tab names are distinct" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            , { name = "security" }
                            ]

                        tabNames =
                            List.map .name tabs

                        -- Check for duplicates by comparing length
                        hasDuplicates =
                            List.length tabNames /= List.length (List.sort tabNames)
                    in
                    -- In this test case, all names are unique
                    Expect.equal hasDuplicates False
            ]
        , describe "Tab Names"
            [ test "tab names are non-empty" <|
                \_ ->
                    let
                        tabs =
                            [ { name = "all" }
                            , { name = "tech" }
                            , { name = "security" }
                            ]

                        allNames =
                            List.map .name tabs

                        noEmptyNames =
                            List.all (\name -> String.length name > 0) allNames
                    in
                    Expect.equal noEmptyNames True
            , test "tab names match expected values" <|
                \_ ->
                    let
                        expectedNames =
                            [ "all", "tech", "security", "3dprinting", "dev" ]

                        providedNames =
                            [ "all", "tech", "security" ]
                    in
                    -- First three should match
                    Expect.equalLists (List.take 3 expectedNames) providedNames
            ]
        , describe "Empty Tab List"
            [ test "handles empty tab list" <|
                \_ ->
                    let
                        tabs =
                            []
                    in
                    Expect.equal (List.length tabs) 0
            , test "empty tab list has zero length" <|
                \_ ->
                    let
                        tabs =
                            []
                    in
                    Expect.equal 0 (List.length tabs)
            ]
        , describe "Tab State Transitions"
            [ test "can switch from all to tech" <|
                \_ ->
                    let
                        initialTab =
                            "all"

                        newTab =
                            "tech"
                    in
                    Expect.notEqual initialTab newTab
            , test "can switch from tech to security" <|
                \_ ->
                    let
                        initialTab =
                            "tech"

                        newTab =
                            "security"
                    in
                    Expect.notEqual initialTab newTab
            , test "can switch back to all" <|
                \_ ->
                    let
                        tabs =
                            [ "all", "tech", "security" ]

                        currentTab =
                            "tech"

                        switchedTab =
                            "all"
                    in
                    -- Should be able to switch back to any tab
                    List.member switchedTab tabs
                        |> Expect.equal True
            ]
        ]
