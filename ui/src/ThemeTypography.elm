module ThemeTypography exposing (..)

import Element.Font as Font


{-|
  Centralized typography helpers.
  Replace scattered `Font.size N` with these named helpers so desktop scaling is consistent.
-}

type alias Attr = Font.Attribute


title : Attr
title =
    Font.size 24


subtitle : Attr
subtitle =
    Font.size 20


body : Attr
body =
    Font.size 16


small : Attr
small =
    Font.size 12


meta : Attr
meta =
    Font.size 11


button : Attr
button =
    Font.size 15


size18 : Attr
size18 =
    Font.size 18


size14 : Attr
size14 =
    Font.size 14


size13 : Attr
size13 =
    Font.size 13


end
