import ../webview/src/webview

import json
import httpclient
import os

echo "starting"

let w = newWebview(debug=true)

w.setSize(640, 400)
w.setTitle("Legends of Equestria Launcher")

w.setBorderless(false)

w.bind("webviewLoaded", proc (args: JsonNode): JsonNode =
  echo "load event!"
)

proc onProgressChanged(total, progress, speed: BiggestInt) =
  echo("Downloaded ", progress, " of ", total)
  echo("Current rate: ", speed div 1000, "kb/s")
  {.gcsafe.}:
    w.dispatch(proc () = w.eval("updateProgress(" & $ progress & ", " & $total & ", " & $speed & ")"))

proc fetch(url: string): string =
  var client = newHttpClient()
  client.onProgressChanged = onProgressChanged
  return client.getContent(url)

w.bind("downloadFile", proc (args: JsonNode): JsonNode =
  let url = args[0].getStr()
  echo "Downloading url: ", url
  var client = newHttpClient()
  w.dispatch(proc () = w.eval("updateProgress(0, 1, 0)"))
  client.onProgressChanged = onProgressChanged
  let content = client.getContent(url)
  echo "Bytes downloaded: ", content.len
  w.dispatch(proc () = w.eval("updateProgress(" & $ content.len & ", " & $content.len & ", 0)"))
  return %* {"length": content.len}
)

w.init("window.addEventListener('load', function (e) {webviewLoaded()}, false)")

w.bind("externalNavigate", proc(args: JsonNode): JsonNode =
  echo "clicked something with a href!"
  let href = args[0]["href"]
  let target = args[0]["target"]
  echo "href: ", href
  echo "target: ", target
)

let uri = "file://" & getCurrentDir() / "static" / "main.html"
echo "navigating to ", uri

w.navigate(uri)
w.run()
w.destroy()
