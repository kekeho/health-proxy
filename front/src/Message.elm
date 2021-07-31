module Message exposing (..)

import Browser
import Url

type Msg
    = RecvSession String
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url