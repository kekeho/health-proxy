import tables
import times
import norm / [model, sqlite]
import std / with
import types

# types

type
  Session* = object
    fromHostname*: string
    toHostname*: string
    request*: ProxyHttpRequest
    response*: HttpResponse
    timestamp*: Time  # UnixTime

type
  ErrorSession = ref object of Model
    fromHostName: string
    toHostname: string

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
  SessionTableKey = tuple[fromHostname: string, toHostname: string]

type
  SessionTable* = Table[SessionTableKey, Session]


# variables

let dbConn = open("db.sqlite3", "", "", "")

# procs

proc newErrorSession(session = Session()): ErrorSession =
  return ErrorSession(
    fromHostname: session.fromHostname,
    toHostname: session.toHostname,

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


block connect:
  dbConn.createTables(newErrorSession())