import asynchttpserver
import asyncdispatch
import net
import asyncfile
import os
import strutils


proc callback(req: Request) {.async.} =
    echo req.url.path
    if req.url.path.startsWith("/static"):
        try:
            let file = openAsync(os.joinPath("front/dist", req.url.path))
            await req.respond(Http200, await file.readAll())
        except OSError:
            await req.respond(Http404, "404 Not Found")
    else:
        let html = openAsync("front/dist/index.html")
        await req.respond(Http200, await html.readAll())


proc callbackWrapper(req: Request) {.async.} =
    try:
        await callback(req)
    except Exception:
        await req.respond(Http500, "An error has occured")


proc httpServer*(address: string, port: Port) {.async.} =
    let server = newAsyncHttpServer()
    server.listen(port, address)

    while true:
        await server.acceptRequest(callbackWrapper)
