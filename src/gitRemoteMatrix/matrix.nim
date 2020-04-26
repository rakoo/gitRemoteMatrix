import consts, os, asyncdispatch, httpClient, json, strutils, uri, tables, osproc

var
  baseUrls = initTable[string, string]()

proc isValid*(uid: string): bool =
  let hasAt = uid.startsWith('@')
  let parts = uid.split(':')
  let has2Parts = parts.len == 2
  let hasSlash = parts[1].contains('/')
  return hasAt and has2Parts and not hasSlash

proc getBaseUrl(userid: string): Future[string] {.async.} =
  var domain = userid.split(':')[1]
  if baseUrls.hasKey(domain):
    return baseUrls[domain]

  # override with well-known if it exists 
  var baseUrl = "https://" & domain
  try:
    let h = newHttpHeaders([("User-Agent", gitRemoteMatrixVersion)])
    let client = newAsyncHttpClient(headers = h)
    let wellKnown = await client.getContent(baseUrl & "/.well-known/matrix/client")
    baseUrl = parseJson(wellKnown)["m.homeserver"]["base_url"].getStr()
  except:
    # No well-known, or it is malformed, we don't care
    discard

  baseUrls[domain] = baseUrl
  result = baseUrl

proc logout*(uid, token: string) {.async.} =
  try:
    let h = newHttpHeaders([
      ("User-Agent", gitRemoteMatrixVersion),
      ("Authorization", "Bearer " & token)])
    let client = newAsyncHttpClient(headers = h)
    let baseUrl = await getBaseUrl(uid)

    let url = combine(parseUri($baseUrl) / "/_matrix/client/r0/logout")
    discard await client.post($url)
  except:
    discard

proc login*(uid, password: string): Future[bool] {.async.} =
  try:
    let h = newHttpHeaders([
      ("User-Agent", gitRemoteMatrixVersion)])
    let client = newAsyncHttpClient(headers = h)
    let baseUrl = await getBaseUrl(uid)

    let loginUrl = combine(parseUri($baseUrl) / "/_matrix/client/r0/login")
    echo "logging to " & $loginUrl

    let loginMethods = await client.getContent($loginUrl)
    let loginMethodsObj = parseJson(loginMethods)
    var has_password: bool
    for flow in loginMethodsObj["flows"].getElems():
      if flow["type"].getStr() != "m.login.password":
        continue
      has_password = true

    if not has_password:
      echo "Server doesn't have m.login.password flow"

    let id = uid.split(':')[0]
    let username = id[1 .. id.len-1]
    
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
    if loginResp.code() != 200.HttpCode:
      echo "Couldn't login: code=" & $loginResp.code()
      let body = await(loginResp.body())
      echo "reply = " & $body

      return false

    echo "logged in"

    let body = await(loginResp.body())
    let accessToken = parseJson(body){"access_token"}
    if accessToken == nil:
      echo "We are logged in but there is no access token"
      return false

    let res = execCmd("git config --replace-all remote.matrix.acces_token." & $uid & " " & accessToken.getStr())
    if res != 0:
      echo "Couldn't set access token in git config"
      return false

    return true
  except:
    return false

