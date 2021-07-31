module Model exposing (..)

import Url
import Browser.Navigation as Nav
import Url.Parser
import Time
import Dict exposing (Dict)

-- Types

type HttpMethod
    = Head
    | Get
    | Post
    | Put
    | Patch
    | Delete
    | Trace
    | Options
    | Connect


type alias ProxyHttpRequest =
    { httpMethod: HttpMethod
    , host: String
    , path: String
    , tcpPort: Int
    , protocol: String
    , headers: List (Dict String String)
    , body: String
    }


type alias HttpResponse =
    { protocol: String
    , statusCode: Int
    , statusMessage: String
    , headers: List (Dict String String)
    , body: String
    }


type alias Session =
    { fromHostName: String
    , toHostName: String
    , request: ProxyHttpRequest
    , response: HttpResponse
    , timestamp: Time.Posix
    }


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , sessions: List Session
    }


type Route
    = IndexPage



-- Functions

initModel : Url.Url -> Nav.Key -> Model
initModel url key =
    Model key url []


-- Route Parser

routeParser : Url.Parser.Parser (Route -> a) a
routeParser =
    Url.Parser.oneOf
        [ Url.Parser.map IndexPage Url.Parser.top ]
