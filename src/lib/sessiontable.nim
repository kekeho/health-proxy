import tables
import times
import norm / [model, sqlite]
import std / with
import types
import re
import strutils
import json
import options
import nativesockets
import strformat

# types

type
  Session* = object
    fromHostName*: string
    toHostName*: string
    request*: ProxyHttpRequest
    response*: HttpResponse
    timestamp*: Time  # UnixTime

type
  DBSession = ref object of Model
    fromHostName: string
    toHostName: string

    requestHttpMethod: string
    requestHost: string
    requestPath: string
    requestPort: int
    requestProtocol: string
    requestHeaders: string  # json
    requestBody: string

    responseProtocol: string
    responseStatusCode: int
    responseStatusMessage: string
    responseHeaders: string # json
    responseBody: string

    timestamp: DateTime

type
  SessionTableKey = tuple[fromHostName: string, toHostName: string]

type
  SessionTable* = Table[SessionTableKey, Session]


# variables

when defined modeTest:
  let dbConn = open("testdb.sqlite3", "", "", "")
  echo "test"
else:
  let dbConn = open("db.sqlite3", "", "", "")

# procs

proc newDBSession(session = Session()): DBSession =
  return DBSession(
    fromHostname: session.fromHostname,
    toHostName: session.toHostname,

    requestHttpMethod: session.request.httpMethod.toStr,
    requestHost: session.request.host,
    requestPath: session.request.path,
    requestPort: session.request.port.int,
    requestProtocol: session.request.protocol,
    requestHeaders: session.request.headers.toJson,
    requestBody: session.request.body,

    responseProtocol: session.response.protocol,
    responseStatusCode: session.response.statusCode.int,
    responseStatusMessage: session.response.statusMessage,
    responseHeaders: session.response.headers.toJson,
    responseBody: session.response.body,

    timestamp: session.timestamp.utc,
  )


proc toSession(dbSession: DBSession): Option[Session] =
  let requestMethod = dbSession.requestHttpMethod.toMethod
  if requestMethod.isNone():
    return none(Session)

  var requestHeaders: seq[HttpHeader]
  let requestHeadersJson = dbSession.requestHeaders.parseJson()

  for r in requestHeadersJson.pairs:
    let h: HttpHeader = (key: r.key, value: r.val.getStr())
    requestHeaders.add(h)
  
  let request: ProxyHttpRequest = ProxyHttpRequest(
    httpMethod: dbSession.requestHttpMethod.toMethod.get(),
    host: dbSession.requestHost,
    path: dbSession.requestPath,
    port: Port(dbSession.requestPort),
    protocol: dbSession.requestProtocol,
    headers: requestHeaders,
    body: dbSession.requestBody,
  )

  var responseHeaders: seq[HttpHeader]
  let responseHeadersJson = dbSession.responseHeaders.parseJson()

  for r in responseHeadersJson.pairs:
    let h: HttpHeader = (key: r.key, value: r.val.getStr())
    responseHeaders.add(h)

  let response = HttpResponse(
    protocol: dbSession.responseProtocol,
    statusCode: dbSession.responseStatusCode.uint16,
    statusMessage: dbSession.responseStatusMessage,
    headers: responseHeaders,
    body: dbSession.responseBody,
  )

  return some(Session(
    fromHostName: dbSession.fromHostName,
    toHostName: dbSession.toHostName,
    request: request,
    response: response,
    timestamp: dbSession.timestamp.toTime,
  ))


proc getSessionsFromDB*(offset: int = 0, limit: int = 1000): seq[Session] =
  var sessions: seq[DBSession] = @[DBSession()]
  dbConn.select(sessions, fmt"1 ORDER BY timestamp DESC LIMIT ? OFFSET ?", limit, offset)

  var res: seq[Session]
  for db_s in sessions:
    let s = db_s.toSession()
    if s.isNone:
      continue  # TODO: ERROR送信
    res.add(s.get())
  return res


proc `[]=`*(t: var SessionTable, key: SessionTableKey, val: Session) =
  var errorSession: DBSession = newDBSession(val)
  with dbConn:
    insert errorSession

  # insert value to table
  tables.`[]=`(t, key, val)


# type
  # Session* = object
  #   fromHostName*: string
  #   toHostName*: string
  #   request*: ProxyHttpRequest
  #   response*: HttpResponse
  #   timestamp*: Time  # UnixTime

proc toJson*(s: Session): string =
  let req = %* {
    "httpMethod": s.request.httpMethod.toStr,
    "host": s.request.host,
    "path": s.request.path,
    "port": s.request.port.int,
    "protocol": s.request.protocol,
    "headers": s.request.headers.toTable,
    "body": s.request.body,
  }
  let resp = %* {
    "protocol": s.response.protocol,
    "statusCode": s.response.statusCode,
    "statusMessage": s.response.statusMessage,
    "headers": s.response.headers.toTable,
    "body": s.response.body,
  }
  let d = %* {
    "fromHostName": s.fromHostName,
    "toHostName": s.toHostName,
    "request": req,
    "response": resp,
    "timestamp": (s.timestamp.toUnixFloat * 1000).int,
  }

  return d.pretty()


block connect:
  dbConn.createTables(newDBSession())