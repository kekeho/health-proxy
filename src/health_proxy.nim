import lib/proxy
import net
import asyncdispatch
import lib/httpserver
import docopt
import strutils



const WEBSOCKET_PORT: int = 8081  # for communicate between browser and health_proxy TODO: 可変にする



const DOC = """health_proxy
Overview:
  A simple proxy to check the traffic of each container in a microservice architecture.
Usage:
  health_proxy <address> <proxy_port> <webconsole_port>
"""

let args = docopt(DOC, version = "0.1.0")
let address: string = $args["<address>"]
let proxy_port = ($args["<proxy_port>"]).parseInt
let web_port = ($args["<webconsole_port>"]).parseInt

proc main() =
  asyncCheck proxyServer(address, Port(proxy_port), Port(WEBSOCKET_PORT))
  asyncCheck httpServer(address, Port(web_port))
  runForever()


when isMainModule:
  main()
