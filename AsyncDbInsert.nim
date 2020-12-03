import parsecsv
import os
import times
import strformat


var tmp_files:seq[string]
let crnt:string=getCurrentDir()
for dir in walkFiles(fmt"{crnt}/*"):
  tmp_files.add(dir)
echo tmp_files