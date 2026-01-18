module TestRunner exposing (tests)

import TabBarTests
import TabSwitchingTests
import Test


tests : Test.Test
tests =
    Test.describe "QuickHeadlines Tab Tests"
        [ TabBarTests.tabBarTests
        , TabSwitchingTests.tabSwitchingTests
        ]
