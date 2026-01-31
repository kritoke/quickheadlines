
module ThemeTypography exposing (..)

import Element exposing (Attribute)
import Element.Font as Font


{-|
  Centralized typography helpers.
  Replace scattered `Font.size N` with these named helpers so desktop scaling is consistent.
 -}


title : Attribute msg
title =
    Font.size 24


subtitle : Attribute msg
subtitle =
    Font.size 20


body : Attribute msg
body =
    Font.size 16


small : Attribute msg
small =
    Font.size 12


meta : Attribute msg
meta =
    Font.size 11


button : Attribute msg
button =
    Font.size 15


size18 : Attribute msg
size18 =
    Font.size 18


size14 : Attribute msg
size14 =
    Font.size 14


size13 : Attribute msg
size13 =
    Font.size 13
