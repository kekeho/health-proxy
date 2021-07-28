import unittest
include ../src/lib/proxy

suite "library test":
  block proxy:  # lib/proxy.nim
    echo "==proxy.nim=="
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
    let request = "GET http://www.example.com HTTP/1.1\c\n" & 
    "Host: www.example.com\c\n" &
    "content-type : text/html; charset=utf-8\c\n" &
    "\c\n" &
    "Hello, World!\c\nhogefuga"

    doAssert request.proxyHttpRequestParser == some(ProxyHttpRequest(
      httpMethod: HttpMethod.Get,
      host: "www.example.com",
      path: "/",
      port: Port(80),
      protocol: "HTTP/1.1",
      headers: @[(key: "Host", value: "www.example.com"), (key: "content-type", value: "text/html; charset=utf-8")],
      body: "Hello, World!\c\nhogefuga",
    ))
  
  test "func HttpResponseParser":
    let resp = "HTTP/1.1 201 Created\c\n" & 
    "Host: www.example.com\c\n" &
    "content-type : text/html; charset=utf-8\c\n" &
    "\c\n" &
    "This is response."

    doAssert resp.HttpResponseParser == some(HttpResponse(
      protocol: "HTTP/1.1",
      statusCode: 201.uint16,
      statusMessage: "Created",
      headers: @[(key: "Host", value: "www.example.com"), (key: "content-type", value: "text/html; charset=utf-8")],
      body: "This is response.",
    ))