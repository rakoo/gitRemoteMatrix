import matrig/git
import strutils

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
  while true:
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
