module Model exposing (..)

import Url
import Browser.Navigation as Nav
import Url.Parser


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    }


type Route
    = IndexPage



initModel : Url.Url -> Nav.Key -> Model
initModel url key =
    Model key url


routeParser : Url.Parser.Parser (Route -> a) a
routeParser =
    Url.Parser.oneOf
        [ Url.Parser.map IndexPage Url.Parser.top ]

