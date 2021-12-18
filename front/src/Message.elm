module Message exposing (..)

import Browser
import Url
import Time
import Model exposing (FilterType)

type Msg
    = GetTimezone Time.Zone
    | RecvSession String
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | ChangeSelectedSession Int
    | AddFilter FilterType
    | DeleteFilter FilterType Int
    | EditFilterEditor FilterType String
