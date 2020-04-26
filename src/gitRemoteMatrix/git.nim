import osproc

proc do_push*(src, dst: string, force: bool) =
  discard

proc log*() =
  let output = execProcess("git", args=["log", "--oneline"], workingDir = "/home/rakoo/dev/jmap-demo-webmail/", options = {poUsePath, poEchoCmd})
  echo output
