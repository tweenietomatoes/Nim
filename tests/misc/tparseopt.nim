discard """
  output: '''
parseopt
first round
kind: cmdLongOption	key:val  --  left:
second round
kind: cmdLongOption	key:val  --  left:
kind: cmdLongOption	key:val  --  debug:3
kind: cmdShortOption	key:val  --  l:4
kind: cmdShortOption	key:val  --  r:2
cmdLongOption foo
cmdLongOption path
parseoptNoVal
kind: cmdLongOption	key:val  --  left:
kind: cmdLongOption	key:val  --  debug:3
kind: cmdShortOption	key:val  --  l:
kind: cmdShortOption	key:val  --  r:2
kind: cmdLongOption	key:val  --  debug:2
kind: cmdLongOption	key:val  --  debug:1
kind: cmdShortOption	key:val  --  r:1
kind: cmdShortOption	key:val  --  r:0
kind: cmdShortOption	key:val  --  l:
kind: cmdShortOption	key:val  --  r:4
parseopt2
first round
kind: cmdLongOption	key:val  --  left:
second round
kind: cmdLongOption	key:val  --  left:
kind: cmdLongOption	key:val  --  debug:3
kind: cmdShortOption	key:val  --  l:4
kind: cmdShortOption	key:val  --  r:2'''
joinable: false
"""

when defined(testament_tparseopt):
  import os
  proc main() =
    let args = commandLineParams()
    echo args
    for i, ai in args:
      echo "arg ", i, " ai.len:", ai.len, " :{", ai, "}"
  main()
else:
  from parseopt import nil
  from parseopt2 import nil

  block:
    echo "parseopt"
    for kind, key, val in parseopt.getopt():
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val

    # pass custom cmdline arguments
    echo "first round"
    var argv = "--left --debug:3 -l=4 -r:2"
    var p = parseopt.initOptParser(argv)
    for kind, key, val in parseopt.getopt(p):
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val
      break
    # reset getopt iterator and check arguments are returned correctly.
    echo "second round"
    for kind, key, val in parseopt.getopt(p):
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val

    # bug #9619
    var x = parseopt.initOptParser(@["--foo:", "--path"],
        allowWhitespaceAfterColon = false)
    for kind, key, val in parseopt.getopt(x):
      echo kind, " ", key

  block:
    echo "parseoptNoVal"
    # test NoVal mode with custom cmdline arguments
    var argv = "--left --debug:3 -l -r:2 --debug 2 --debug=1 -r1 -r=0 -lr4"
    var p = parseopt.initOptParser(argv,
                                    shortNoVal = {'l'}, longNoVal = @["left"])
    for kind, key, val in parseopt.getopt(p):
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val

  block:
    echo "parseopt2"
    for kind, key, val in parseopt2.getopt():
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val

    # pass custom cmdline arguments
    echo "first round"
    var argv: seq[string] = @["--left", "--debug:3", "-l=4", "-r:2"]
    var p = parseopt2.initOptParser(argv)
    for kind, key, val in parseopt2.getopt(p):
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val
      break
    # reset getopt iterator and check arguments are returned correctly.
    echo "second round"
    for kind, key, val in parseopt2.getopt(p):
      echo "kind: ", kind, "\tkey:val  --  ", key, ":", val

  import osproc, os, strutils
  from stdtest/specialpaths import buildDir
  import "../.." / compiler/unittest_light

  block: # fix #9951 (and make it work for parseopt and parseopt2)
    template runTest(parseoptCustom) =
      var p = parseoptCustom.initOptParser(@["echo \"quoted\""])
      let expected = when defined(windows):
        """"echo \"quoted\"""""
      else:
        """'echo "quoted"'"""
      assertEquals parseoptCustom.cmdLineRest(p), expected

      doAssert "a5'b" == "a5\'b"

      let args = @["a1b", "a2 b", "", "a4\"b", "a5'b", r"a6\b", "a7\'b"]
      var p2 = parseoptCustom.initOptParser(args)
      let expected2 = when defined(windows):
        """a1b "a2 b" "" a4\"b a5'b a6\b a7'b"""
      else:
        """a1b 'a2 b' '' 'a4"b' 'a5'"'"'b' 'a6\b' 'a7'"'"'b'"""
      doAssert "a5'b" == "a5\'b"
      assertEquals parseoptCustom.cmdLineRest(p2), expected2
    runTest(parseopt)
    runTest(parseopt2)

  block: # fix #9842
    let exe = buildDir / "D20190112T145450".addFileExt(ExeExt)
    defer: removeFile exe
    let args = @["a1b", "a2 b", "", "a4\"b", "a5'b", r"a6\b", "a7\'b"]
    let cmd = "$# c -r --verbosity:0 -o:$# -d:testament_tparseopt $# $#" %
      [getCurrentCompilerExe(), exe, currentSourcePath(),
          args.quoteShellCommand]
    var ret = execCmdEx(cmd, options = {})
    if ret.exitCode != 0:
      # before bug fix, running cmd would show:
      # sh: -c: line 0: unexpected EOF while looking for matching `"'\n
      echo "exitCode: ", ret.exitCode, " cmd:", cmd
      doAssert false
    stripLineEnd(ret.output)
    assertEquals ret.output,
      """
@["a1b", "a2 b", "", "a4\"b", "a5\'b", "a6\\b", "a7\'b"]
arg 0 ai.len:3 :{a1b}
arg 1 ai.len:4 :{a2 b}
arg 2 ai.len:0 :{}
arg 3 ai.len:4 :{a4"b}
arg 4 ai.len:4 :{a5'b}
arg 5 ai.len:4 :{a6\b}
arg 6 ai.len:4 :{a7'b}"""
