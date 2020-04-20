import os, asyncdispatch, httpClient, json, strutils, uri, terminal

type
  InputError = object of CatchableError
  ServerError = object of CatchableError

const
  userAgent = "git-remote-matrix v0.1"

template must(y: bool) =
  if not y:
    raise newException(InputError, "Invalid input")

proc dostuff() {.async.} =
  let h = newHttpHeaders([("User-Agent", $userAgent)])
  let client = newAsyncHttpClient(headers = h)

  let userid = execCmdEx("git config --get remote.matrix.userid")

  must userid.split(':').len == 2
  var base_url = userid.split(':')[1]

  # override with well-known if it exists 
  try:
    let wellKnown = await client.getContent("https://" & $base_url & "/.well-known/matrix/client")
    base_url = parseJson(wellKnown)["m.homeserver"]["base_url"].getStr()
  except:
    # No well-known, or it is malformed, we don't care
    discard

  let loginUrl = combine(parseUri(base_url), parseUri("/_matrix/client/r0/login"))
  try:
    let loginMethods = await client.getContent($loginUrl)
    let loginMethodsObj = parseJson(loginMethods)
    var has_password: bool
    for flow in loginMethodsObj["flows"].getElems():
      if flow["type"].getStr() != "m.login.password":
        continue
      has_password = true

    if not has_password:
      raise newException(ServerError, "Server doesn't have m.login.password flow")

    let id = user_id.split(':')[0]
    let username = id[1 .. id.len-1]
    let password = readPasswordFromStdin()

    let passwordRequest = %*{
      "type": "m.login.password",
      "identifier": {
        "type": "m.id.user",
        "user": username
      },
      "password": password,
      "initial_device_display_name": "Jungle Phone"
    }
    let loginResp = await client.post($loginUrl, $passwordRequest)
    echo loginResp.code()
    echo await loginResp.body()
  except ServerError:
    echo "No available login methods"

must paramCount() == 1
let userid = paramStr(1)
waitFor dostuff(userid)
