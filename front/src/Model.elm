module Model exposing (..)

import Url
import Browser.Navigation as Nav
import Url.Parser
import Time
import Json.Decode as D
import String exposing (toUpper)

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
    | Other String


type alias ProxyHttpRequest =
    { httpMethod: HttpMethod
    , host: String
    , path: String
    , tcpPort: Int
    , protocol: String
    , headers: List (String, String)
    , body: String
    }


type alias HttpResponse =
    { protocol: String
    , statusCode: Int
    , statusMessage: String
    , headers: List (String, String)
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


strToHttpMethod: String -> HttpMethod
strToHttpMethod str =
    case toUpper str of
        "HEAD" ->
            Head
        "GET" ->
            Get
        "POST" ->
            Post
        "PUT" ->
            Put
        "PATCH" ->
            Patch
        "DELETE" ->
            Delete
        "TRACE" ->
            Trace
        "OPTIONS" ->
            Options
        "CONNECT" ->
            Connect
        _ ->
            Other str


initModel : Url.Url -> Nav.Key -> Model
initModel url key =
    Model key url []


-- Route Parser

routeParser : Url.Parser.Parser (Route -> a) a
routeParser =
    Url.Parser.oneOf
        [ Url.Parser.map IndexPage Url.Parser.top ]


-- JSON Decoder

proxyHttpRequestDecoder : D.Decoder ProxyHttpRequest
proxyHttpRequestDecoder =
    D.map7 ProxyHttpRequest
        (D.field "httpMethod" (D.map strToHttpMethod D.string))
        (D.field "host" D.string)
        (D.field "path" D.string)
        (D.field "port" D.int)
        (D.field "protocol" D.string)
        (D.field "headers" (D.keyValuePairs D.string))
        (D.field "body" D.string)


httpResponseDecoder : D.Decoder HttpResponse
httpResponseDecoder =
    D.map5 HttpResponse
        (D.field "protocol" D.string)
        (D.field "statusCode" D.int)
        (D.field "statusMessage" D.string)
        (D.field "headers" (D.keyValuePairs D.string))
        (D.field "body" D.string)


sessionDecoder : D.Decoder Session
sessionDecoder =
    D.map5 Session
        (D.field "fromHostName" D.string)
        (D.field "toHostName" D.string)
        (D.field "request" proxyHttpRequestDecoder)
        (D.field "response" httpResponseDecoder)
        (D.field "timestamp" (D.map Time.millisToPosix D.int))
