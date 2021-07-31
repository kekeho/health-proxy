import lib/proxy
import net
import asyncdispatch


proc main() =
  asyncCheck proxyServer("0.0.0.0", Port(8080), Port(8081))
  runForever()


when isMainModule:
  main()
