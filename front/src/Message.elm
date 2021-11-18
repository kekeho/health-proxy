module Message exposing (..)

import Browser
import Url
import Time

type Msg
    = GetTimezone Time.Zone
    | RecvSession String
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url