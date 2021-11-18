import options
import strutils
import net
import asyncnet
import asyncdispatch
import times
import nativesockets
import asynchttpserver
import ws

import types
import sessiontable
import ws
import osproc

# variable

# Store the latest session by source and destination.
var latestSession: SessionTable
var socketsList: seq[WebSocket]

# Function

proc nkf(str: string): Option[string] =
  let r = execCmdEx("nkf", options = {poUsePath}, input=str)
  if r.exitCode != 0:
    return none(string)
  return some(r.output)


func parseRequestFirstLine(str: string): Option[tuple[httpMethod: types.HttpMethod, host: string, port: Port, path: string, protocol: string]] =
  ## str -> (httpMethod, host, port, path, protocol)
  ## "GET http://example.com:8000/hoge HTTP/1.1" -> (HttpMethod.GET, "example.com", Port(8000), "/hoge", "HTTP/1.1")
  
  const failedResult = none(tuple[httpMethod: types.HttpMethod, host: string, port: Port, path: string, protocol: string])

  try:
    let splitted = str.split(' ')

    # method
    let maybeHttpMethod: Option[types.HttpMethod] = splitted[0].toMethod
    if maybeHttpMethod.isNone:
      return failedResult
    let httpMethod: types.HttpMethod = splitted[0].toMethod.get()

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


func proxyHttpRequestParser(rawData: string): Option[ProxyHttpRequest] =
  let rawHeaderAndBody = rawData.split("\r\n\r\n")
  
  try:
    let 
      rawTopAndHeaderLines = rawHeaderAndBody[0].split("\r\n")
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


func httpResponseParser(rawData: string): Option[HttpResponse] =
  let rawHeaderAndBody = rawData.split("\r\n\r\n")
  
  try:
    let 
      rawTopAndHeaderLines = rawHeaderAndBody[0].split("\r\n")
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


proc broadcast(content: string) {.async.} =
  var newSocketsList: seq[WebSocket]

  for socket in socketsList:
    try:
      let c = nkf(content)
      if c.isNone:
        continue  # TODO: send error
      else:
        await socket.send(c.get())
    except WebSocketClosedError:
      continue
    except WebSocketError:
      continue
    newSocketsList.add(socket)

  socketsList = newSocketsList


proc processSession(client: AsyncSocket, clientAddr: string) {.async.} =
  echo clientAddr
  # first line
  let firstLine = await client.recvLine()
  let maybeFst = firstLine.parseRequestFirstLine()
  if maybeFst.isNone:
    client.close()
    return

  let fst = maybeFst.get()
  let host = newAsyncSocket(buffered=false)
  try:
    await host.connect(fst.host, fst.port)
  except OSError:
    # name or service not known
    # TODO: 宛先がない場合, Proxyはどうclientに返信すればいいのか
    client.close()
    host.close()
    return

  await host.send([fst.httpMethod.toStr, fst.path, fst.protocol].join(" ") & "\r\n")

  const bufsize = 1024
  var 
    requestRaw = firstLine & "\r\n"
    responseRaw: string
  # client -> host (request)
  while true:
    let c2hbuf = await client.recv(bufsize)
    await host.send(c2hbuf)
    requestRaw &= c2hbuf
    if c2hbuf.len < bufsize:      
      break
  
  # host -> client (response)
  while true:
    let h2cbuf = await host.recv(bufsize)
    await client.send(h2cbuf)
    responseRaw &= h2cbuf
    if h2cbuf.len == 0:
      break

  if not client.isClosed:
    client.close()
  if not host.isClosed:
    host.close()

  let maybeProxyHttpRequest = requestRaw.proxyHttpRequestParser
  let maybeHttpResponse = responseRaw.httpResponseParser
  if maybeProxyHttpRequest.isNone or maybeHttpResponse.isNone:
    return

  let fromHostname = try:
    clientAddr.getHostByAddr.name
  except OSError:
    clientAddr

  let session: Session = Session(
    fromHostname: fromHostname,
    toHostname: maybeProxyHttpRequest.get.host,
    request: maybeProxyHttpRequest.get,
    response: maybeHttpResponse.get,
    timestamp: getTime(),
  )

  latestSession[(fromHostname: session.fromHostname, toHostname: session.toHostname)] = session
  await broadcast (session.toJson)

  return

proc socketCallback(req: Request) {.async, gcsafe.} =
  if req.url.path == "/socket":
    try:
      var ws = await newWebSocket(req)
      socketsList.add(ws)

      while ws.readyState == Open:
        await sleepAsync(1000)

    except WebSocketClosedError:
      echo "closed"
    
    except WebSocketProtocolMismatchError:
      echo "Protocol Mismatch"
    
    except WebSocketError:
      echo "Unexpected error"
    
  await req.respond(Http404, "Not Found")


proc socketServer*(port: Port, address: string) =
  let server = newAsyncHttpServer()
  asyncCheck server.serve(port, socketCallback, address)


proc proxyServer*(address: string, proxyPort: Port, wsPort: Port) {.async.} =
  let server = newAsyncSocket(buffered=false)
  server.setSockOpt(OptReusePort, true)
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(proxyPort, address)
  server.listen()

  socketServer(wsPort, address)

  while true:
    let (address, client) = await server.acceptAddr()
    asyncCheck client.processSession(address)
