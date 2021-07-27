# Package

version       = "0.1.0"
author        = "Hiroki.T"
description   = "A simple proxy to check the health of each container in a microservice architecture"
license       = "MIT"
srcDir        = "src"
bin           = @["health_proxy"]


# Dependencies

requires "nim >= 1.4.8"
