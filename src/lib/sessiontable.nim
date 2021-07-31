import tables
import times
import norm / [model, sqlite]
import std / with
import types
import strutils
import json

# types

type
  Session* = object
    fromHostName*: string
    toHostName*: string
    request*: ProxyHttpRequest
    response*: HttpResponse
    timestamp*: Time  # UnixTime

type
  ErrorSession = ref object of Model
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

proc newErrorSession(session = Session()): ErrorSession =
  return ErrorSession(
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


proc `[]=`*(t: var SessionTable, key: SessionTableKey, val: Session) =
  # record 5xx, 400, 405, 411, 412, 413, 414, 415, 417, 418, 421, 429, 431 error
  var recordFlag: bool = false
  if int(val.response.statusCode.int / 100) == 5:
    recordFlag = true
  elif val.response.statusCode.int in [
    400, 405, 411, 412, 413, 414, 415, 417, 418, 421, 429, 431
  ]: 
    recordFlag = true
  
  if recordFlag:
    var errorSession: ErrorSession = newErrorSession(val)
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
  dbConn.createTables(newErrorSession())