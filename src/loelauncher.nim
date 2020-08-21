import ../webview/src/webview

import json
import httpclient
import os
import asynchttpserver, asyncdispatch
import threadpool

spawn (proc () =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    echo " --> request"
    await req.respond(Http200, "Hello World")
    echo " <-- response"

  waitFor server.serve(Port(8080), cb, "127.0.0.1")
)()

echo "starting"

let w = newWebview(debug=true)

w.setSize(640, 400)
w.setTitle("Legends of Equestria Launcher")

w.setBorderless(false)

w.bind("webviewLoaded", proc (args: JsonNode): JsonNode =
  echo "load event!"
)


proc fetch(url: string): string =
  var client = newHttpClient()
  client.onProgressChanged = proc (total, progress, speed: BiggestInt) =
    echo("Downloaded ", progress, " of ", total)
    echo("Current rate: ", speed div 1000, "kb/s")
    {.gcsafe.}:
      w.dispatch(proc () = w.eval("updateProgress(" & $ progress & ", " & $total & ", " & $speed & ")"))

  return client.getContent(url)

w.init("window.addEventListener('load', function (e) {webviewLoaded()}, false)")

w.bind("externalNavigate", proc(args: JsonNode): JsonNode =
  echo "clicked something with a href!"
  let href = args[0]["href"]
  let target = args[0]["target"]
  echo "href: ", href
  echo "target: ", target
)

let uri = "file://" & getAppDir() / "static" / "main.html"
echo "navigating to ", uri

w.navigate(uri)
w.run()
w.destroy()
