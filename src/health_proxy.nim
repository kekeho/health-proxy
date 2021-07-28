import lib/proxy
import net
import asyncdispatch


proc main() =
  asyncCheck proxyServer("0.0.0.0", Port(8080))
  runForever()


when isMainModule:
  main()
