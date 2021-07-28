import net
import options
import strutils


type
  HttpMethod* = enum
    Head,
    Get,
    Post,
    Put,
    Patch,
    Delete,
    Trace,
    Options,
    Connect,


type
  HttpHeader* = tuple[key: string, value: string]


type
  ProxyHttpRequest* = object
    httpMethod*: HttpMethod
    host*: string
    path*: string
    port*: Port
    protocol*: string
    headers*: seq[HttpHeader]
    body*: string


type
  HttpResponse* = object
    protocol*: string
    statusCode*: uint16
    statusMessage*: string
    headers*: seq[HttpHeader]
    body*: string


# functions

func toMethod*(str: string): Option[HttpMethod] =
  case str.toUpper
  of "HEAD":
    return some(HttpMethod.Head)
  of "GET":
    return some(HttpMethod.Get)
  of "POST":
    return some(HttpMethod.Post)
  of "PUT":
    return some(HttpMethod.Put)
  of "PATCH":
    return some(HttpMethod.Patch)
  of "DELETE":
    return some(HttpMethod.Delete)
  of "TRACE":
    return some(HttpMethod.Trace)
  of "OPTIONS":
    return some(HttpMethod.Options)
  of "CONNECT":
    return some(HttpMethod.Connect)

  return none(HttpMethod)


func toStr*(m: HttpMethod): string =
  return case m
    of HttpMethod.Head:
      "HEAD"
    of HttpMethod.Get:
      "GET"
    of HttpMethod.Post:
      "POST"
    of HttpMethod.Put:
      "PUT"
    of HttpMethod.Patch:
      "PATCH"
    of HttpMethod.Delete:
      "DELETE"
    of HttpMethod.Trace:
      "TRACE"
    of HttpMethod.Options:
      "OPTIONS"
    of HttpMethod.Connect:
      "CONNECT"


func toJson*(headers: seq[HttpHeader]): string =
  var headersList: seq[string]
  for header in headers:
    let s = "{\"" & header.key & "\":\"" & header.value & "\"}"
    headersList.add(s)
  
  return "[" & headersList.join(",") & "]"
