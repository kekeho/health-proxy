import lib/proxy
import net
import asyncdispatch


const PROXY_PORT: int = 8080
const WEBSOCKET_PORT: int = 8081  # for communicate between browser and health_proxy


proc main() =
  asyncCheck proxyServer("0.0.0.0", Port(PROXY_PORT), Port(WEBSOCKET_PORT))
  runForever()


when isMainModule:
  main()
