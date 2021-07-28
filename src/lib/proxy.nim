import options
import strutils
import strformat
import net
import asyncnet
import asyncdispatch


# Type

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

# Function

func toMethod(str: string): Option[HttpMethod] =
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


func parseRequestFirstLine(str: string): Option[tuple[httpMethod: HttpMethod, host: string, port: Port, path: string, protocol: string]] =
  ## str -> (httpMethod, host, port, path, protocol)
  ## "GET http://example.com:8000/hoge HTTP/1.1" -> (HttpMethod.GET, "example.com", Port(8000), "/hoge", "HTTP/1.1")
  
  const failedResult = none(tuple[httpMethod: HttpMethod, host: string, port: Port, path: string, protocol: string])

  try:
    let splitted = str.split(' ')

    # method
    let maybeHttpMethod: Option[HttpMethod] = splitted[0].toMethod
    if maybeHttpMethod.isNone:
      return failedResult
    let httpMethod: HttpMethod = splitted[0].toMethod.get()

    # host
    if splitted[1].contains("https://"):
      # HTTPS method is not supported
      return failedResult

    let host_path = splitted[1].replace("http://", "").split("/")
    let host: string = host_path[0].split(":")[0]

    # port
    let port: Port = if host_path[0].contains(":"): Port(host_path[0].split(":")[1].parseInt) else: Port(80)
    
    # path
    let path: string = "/" & host_path[1..host_path.len-1].join("/")

    return some((
      httpMethod: httpMethod,
      host: host,
      port: port,
      path: path,
      protocol: splitted[2]
    ))

  except IndexDefect, ValueError:
    return failedResult


func parseResponseFirstLine(str: string): Option[tuple[protocol: string, statusCode: uint16, statusMessage: string]] =
  const failedResult = none(tuple[protocol: string, statusCode: uint16, statusMessage: string])
  try:
    let splitted: seq[string] = str.split(' ')
    let protocol: string = splitted[0]
    let statusCode: uint16 = splitted[1].parseUInt.uint16
    let statusMessage: string = splitted[2..splitted.len-1].join(" ")

    return some((protocol: protocol, statusCode: statusCode, statusMessage: statusMessage))
  except IndexDefect, ValueError:
    return failedResult


func parseHeaderBlock(headerLines: seq[string]): Option[seq[HttpHeader]] =
  var headers: seq[HttpHeader]
  const failedResult = none(seq[HttpHeader])

  try:
    for line in headerLines:
      if not line.contains(":"):
        return failedResult
      let splitted = line.split(":")
      let kv = (key: splitted[0].strip(), value: splitted[1..splitted.len-1].join(":").strip())
      headers.add(kv)    
  except IndexDefect:
    return failedResult

  return some(headers)


func proxyHttpRequestParser*(rawData: string): Option[ProxyHttpRequest] =
  let rawHeaderAndBody = rawData.split("\c\n\c\n")
  
  try:
    let 
      rawTopAndHeaderLines = rawHeaderAndBody[0].split("\c\n")
      body = rawHeaderAndBody[1]
    
    # top
    let maybeTop = parseRequestFirstLine(rawTopAndHeaderLines[0])
    if maybeTop.isNone:
      return none(ProxyHttpRequest)
    let top = maybeTop.get()

    # headers
    let maybeHeaders = parseHeaderBlock(rawTopAndHeaderLines[1..rawTopAndHeaderLines.len-1])
    if maybeHeaders.isNone:
      return none(ProxyHttpRequest)
    let headers: seq[HttpHeader] = maybeHeaders.get()

    return some(ProxyHttpRequest(
      httpMethod: top.httpMethod,
      host: top.host,
      path: top.path,
      port: top.port,
      protocol: top.protocol,
      headers: headers,
      body: body,
    ))

  except IndexDefect:
    return none(ProxyHttpRequest)


func HttpResponseParser*(rawData: string): Option[HttpResponse] =
  let rawHeaderAndBody = rawData.split("\c\n\c\n")
  
  try:
    let 
      rawTopAndHeaderLines = rawHeaderAndBody[0].split("\c\n")
      body = rawHeaderAndBody[1]
    
    # top
    let maybeTop = parseResponseFirstLine(rawTopAndHeaderLines[0])
    if maybeTop.isNone:
      return none(HttpResponse)
    let top = maybeTop.get()

    # headers
    let maybeHeaders = parseHeaderBlock(rawTopAndHeaderLines[1..rawTopAndHeaderLines.len-1])
    if maybeHeaders.isNone:
      return none(HttpResponse)
    let headers: seq[HttpHeader] = maybeHeaders.get()

    return some(HttpResponse(
      protocol: top.protocol,
      statusCode: top.statusCode,
      statusMessage: top.statusMessage,
      headers: headers,
      body: body,
    ))

  except IndexDefect:
    return none(HttpResponse)
