import unittest
import times
import net

include ../src/lib/proxy
import ../src/lib/types
include ../src/lib/sessiontable

suite "library test | proxy.nim":
  test "func parseRequestFirstLine":
    doAssert "GET http://example.com:8000/hoge HTTP/1.1".parseRequestFirstLine == some((
      httpMethod: HttpMethod.Get, host: "example.com", port: Port(8000), path: "/hoge", protocol: "HTTP/1.1",
    ))
    doAssert "POST http://www.example.com:8000/hoge HTTP/1.1".parseRequestFirstLine == some((
      httpMethod: HttpMethod.Post, host: "www.example.com", port: Port(8000), path: "/hoge", protocol: "HTTP/1.1",
    ))
    doAssert "DELETE http://example.com/hoge HTTP/1.1".parseRequestFirstLine == some((
      httpMethod: HttpMethod.Delete, host: "example.com", port: Port(80), path: "/hoge", protocol: "HTTP/1.1",
    ))
    doAssert "GET https://example.com:8000/hoge HTTP/1.1".parseRequestFirstLine == none(tuple[
      httpMethod: HttpMethod, host: string, port: Port, path: string, protocol: string,
    ])
  
  test "func parseResponseFirstLine":
    doAssert "HTTP/1.1 200 OK".parseResponseFirstLine == some((
      protocol: "HTTP/1.1", statusCode: 200.uint16, statusMessage: "OK"
    ))
    doAssert "HTTP/1.1 204 No Content".parseResponseFirstLine == some((
      protocol: "HTTP/1.1", statusCode: 204.uint16, statusMessage: "No Content"
    ))
    doAssert "HTTP/1.1 404 Not Found".parseResponseFirstLine == some((
      protocol: "HTTP/1.1", statusCode: 404.uint16, statusMessage: "Not Found"
    ))
    doAssert "HTTP/1.1 999 Hello, World.".parseResponseFirstLine == some((
      protocol: "HTTP/1.1", statusCode: 999.uint16, statusMessage: "Hello, World."
    ))
    doAssert "HTTP/1.1Hello, World.".parseResponseFirstLine == none(tuple[
      protocol: string, statusCode: uint16, statusMessage: string,
    ])
  
  test "func parseHeaderBlock":
    let headers1 = @[
      "Allow: OPTIONS, GET, HEAD, POST",
      "Cache-Control: max-age=604800",
      "Date: Thu, 13 Oct 2016 11:45:00 GMT",
      "Expires: Thu, 20 Oct 2016 11:45:00 GMT",
      "Server: EOS (lax004/2813)",
      "x-ec-custom-error: 1",
    ]
    doAssert headers1.parseHeaderBlock == some(@[
      (key: "Allow", value: "OPTIONS, GET, HEAD, POST"),
      (key: "Cache-Control", value: "max-age=604800"),
      (key: "Date", value: "Thu, 13 Oct 2016 11:45:00 GMT"),
      (key: "Expires", value: "Thu, 20 Oct 2016 11:45:00 GMT"),
      (key: "Server", value: "EOS (lax004/2813)"),
      (key: "x-ec-custom-error", value: "1"),
    ])

    let headers2 = @[
      "content-type : text/html; charset=utf-8",
      "x-content-type-options : nosniff",
      "x-frame-options : DENY",
      "x-xss-protection : 1; mode=block",
    ]
    doAssert headers2.parseHeaderBlock == some(@[
      (key: "content-type", value: "text/html; charset=utf-8"),
      (key: "x-content-type-options", value: "nosniff"),
      (key: "x-frame-options", value: "DENY"),
      (key: "x-xss-protection", value: "1; mode=block"),
    ])

    let headers3 = @[
      "hogefuga, piyotaro",
    ]
    doAssert headers3.parseHeaderBlock == none(seq[HttpHeader])

  test "func proxyHttpRequestParser":
    let request = "GET http://www.example.com HTTP/1.1\r\n" & 
    "Host: www.example.com\r\n" &
    "content-type : text/html; charset=utf-8\r\n" &
    "\r\n" &
    "Hello, World!\r\nhogefuga"

    doAssert request.proxyHttpRequestParser == some(ProxyHttpRequest(
      httpMethod: HttpMethod.Get,
      host: "www.example.com",
      path: "/",
      port: Port(80),
      protocol: "HTTP/1.1",
      headers: @[(key: "Host", value: "www.example.com"), (key: "content-type", value: "text/html; charset=utf-8")],
      body: "Hello, World!\r\nhogefuga",
    ))
  
  test "func HttpResponseParser":
    let resp = "HTTP/1.1 201 Created\r\n" & 
    "Host: www.example.com\r\n" &
    "content-type : text/html; charset=utf-8\r\n" &
    "\r\n" &
    "This is response."

    doAssert resp.httpResponseParser == some(HttpResponse(
      protocol: "HTTP/1.1",
      statusCode: 201.uint16,
      statusMessage: "Created",
      headers: @[(key: "Host", value: "www.example.com"), (key: "content-type", value: "text/html; charset=utf-8")],
      body: "This is response.",
    ))


suite "library test | types.nim":
  test "func toMethod":
    doAssert toMethod("GET") == some(HttpMethod.Get)
    doAssert toMethod("get") == some(HttpMethod.Get)
    doAssert toMethod("Get") == some(HttpMethod.Get)
    
    doAssert toMethod("HEAD") == some(HttpMethod.Head)
    doAssert toMethod("POST") == some(HttpMethod.Post)
    doAssert toMethod("PUT") == some(HttpMethod.Put)
    doAssert toMethod("PATCH") == some(HttpMethod.Patch)
    doAssert toMethod("DELETE") == some(HttpMethod.Delete)
    doAssert toMethod("TRACE") == some(HttpMethod.Trace)
    doAssert toMethod("OPTIONS") == some(HttpMethod.Options)
    doAssert toMethod("CONNECT") == some(HttpMethod.Connect)

    doAssert toMethod("OPTION") == none(HttpMethod)
    doAssert toMethod("GETWILD") == none(HttpMethod)
    doAssert toMethod("hogefuga") == none(HttpMethod)
  
  test "func toStr":
    doAssert HttpMethod.Get.toStr == "GET"
    doAssert HttpMethod.Head.toStr == "HEAD"
    doAssert HttpMethod.Post.toStr == "POST"
    doAssert HttpMethod.Put.toStr == "PUT"
    doAssert HttpMethod.Patch.toStr == "PATCH"
    doAssert HttpMethod.Delete.toStr == "DELETE"
    doAssert HttpMethod.Trace.toStr == "TRACE"
    doAssert HttpMethod.Options.toStr == "OPTIONS"
    doAssert HttpMethod.Connect.toStr == "CONNECT"


suite "library test | sessiontable.nim":
  test "func newErrorSession":
    let n: Time = getTime()
    let expected = ErrorSession(
      fromHostName: "example.local",
      toHostName: "www.hogefuga.com",
      requestHttpMethod: "GET",
      requestHost: "www.hogefuga.com",
      requestPath: "/index.html",
      requestPort: 80,
      requestProtocol: "HTTP/1.1",
      requestHeaders: toJson(@[(key: "Content-Type", value: "text/html")]),
      requestBody: "",

      responseProtocol: "HTTP/1.1",
      responseStatusCode: 404,
      responseStatusMessage: "Not Found",
      responseHeaders: toJson(@[]),
      responseBody: "Contents not found.",
      timestamp: n.utc,
    )

    let session = Session(
      fromHostName: "example.local",
      toHostName: "www.hogefuga.com",
      request: ProxyHttpRequest(
        httpMethod: HttpMethod.Get,
        host: "www.hogefuga.com",
        path: "/index.html",
        port: Port(80),
        protocol: "HTTP/1.1",
        headers: @[(key: "Content-Type", value: "text/html")],
        body: "",
      ),
      response: HttpResponse(
        protocol: "HTTP/1.1",
        statusCode: 404,
        statusMessage: "Not Found",
        headers: @[],
        body: "Contents not found.",
      ),
      timestamp: n,
    )

    let result = newErrorSession(session)
    doAssert result.fromHostName == expected.fromHostName
    doAssert result.toHostName == expected.toHostName
    doAssert result.requestHttpMethod == expected.requestHttpMethod
    doAssert result.requestHost == expected.requestHost
    doAssert result.requestPath == expected.requestPath
    doAssert result.requestPort == expected.requestPort
    doAssert result.requestProtocol == expected.requestProtocol
    doAssert result.requestHeaders == expected.requestHeaders
    doAssert result.requestBody == expected.requestBody
    doAssert result.responseProtocol == expected.responseProtocol
    doAssert result.responseStatusCode == expected.responseStatusCode
    doAssert result.responseStatusMessage == expected.responseStatusMessage
    doAssert result.responseHeaders == expected.responseHeaders
    doAssert result.responseBody == expected.responseBody
    doAssert result.timestamp == expected.timestamp

  test "proc `[]=`":
    let now = getTime()
    var sessionTable: SessionTable
    let key: SessionTableKey = (fromHostName: "example.local", toHostName: "www.hogefuga.com")
    let valSession = Session(
      fromHostName: "example.local",
      toHostName: "www.hogefuga.com",
      request: ProxyHttpRequest(
        httpMethod: HttpMethod.Get,
        host: "www.hogefuga.com",
        path: "/index.html",
        port: Port(80),
        protocol: "HTTP/1.1",
        headers: @[(key: "Content-Type", value: "text/html")],
        body: "",
      ),
      response: HttpResponse(
        protocol: "HTTP/1.1",
        statusCode: 501,
        statusMessage: "Hoge",
        headers: @[],
        body: "Uoooo",
      ),
      timestamp: now,
    )

    sessionTable[key] = valSession
    doAssert sessionTable.len == 1
    doAssert sessionTable[key] == valSession
    doAssert dbConn.count(ErrorSession) == 1
