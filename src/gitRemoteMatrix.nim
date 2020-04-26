import strutils, osproc, terminal, asyncdispatch
import docopt

import gitRemoteMatrix/consts
import gitRemoteMatrix/git
import gitRemoteMatrix/matrix

proc readLineSafe(s: File): string =
    try:
      result = readLine stdin
    except EOFError:
      discard

proc push(initialLine: string) =
  var line = initialLine

  template checkOrBail(y: bool) =
    if not y:
      line = stdin.readLineSafe
      if line == "":
        break
      continue


  while true:
    checkOrBail line.startsWith("push ")
    checkOrBail line.split(' ').len == 2
    checkOrBail line.split(' ')[1] != ""

    let refspec = line.split(' ')[1]
    checkOrBail refspec.split(':').len == 2
    let dst = refspec.split(':')[1]

    let srcWithPlus = refspec.split(':')[0]
    var src: string
    var force: bool
    if srcWithPlus.startsWith('+'):
      force = true
      src = srcWithPlus[1..srcWithPlus.len-1]
    else:
      src = srcWithPlus

    do_push(src, dst, force)

    line = stdin.readLineSafe
    if line == "":
      break

when isMainModule:
  let doc = """
git-remote-matrix

A git remote helper for storing git stuff in a Matrix.org room

Usage:
  git-remote-matrix --reset-identity <@username:server.tld>
  git-remote-matrix --version

Options:
  --version  Version
  --reset-identity=<@username:server.tld>  Setup with your credentials
"""

  let args = docopt(doc, version = gitRemoteMatrixVersion)
  if args["--reset-identity"]:
    let uid = args["--reset-identity"]
    if not isValid($uid):
      stderr.writeLine "Invalid uid"
      discard
    let password = readPasswordFromStdin()
    let (accessToken, _) = execCmdEx("git config --get remote.matrix.acces_token." & $uid)
    if accessToken != "":
      echo "accessToken found for " & $uid & ", logging out"
      waitFor logout($uid, accessToken)
      echo "logged out"
    
    let loggedIn = waitFor login($uid, password)
    if not loggedIn:
      echo "Invalid uid or password"
      quit(QuitFailure)


  while false:
    let line = stdin.readLineSafe

    if line.startsWith "capabilities":
      #stdout.writeLine "option" 
      stdout.writeLine "push"
      stdout.writeLine "fetch"
      stdout.writeLine ""
    elif line.startsWith "push":
      push(line)
    elif line.startsWith "fetch":
      discard
    elif line == "":
        break
    else: discard
