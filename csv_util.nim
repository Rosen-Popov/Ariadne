import tables
import parsecsv
import intsets
import os
import times
import strformat
import strutils

proc PosInCont[T](container:seq[T],item:T):int=
  for pos in 0..container.high():
    if container[pos] == item:
      return pos
  return -1

proc DateToday():string=
  result = (now().utc() + 2.hours).format("dd-MM-yyyy") & ".csv" 

proc FilterCurrent*(table:var Table[string,seq[string]],files:seq[string],uni_key:string)=
  var PositionFilter:IntSet=initIntSet()
  var table_res:Table[string,seq[string]]
  for fpath in items(files):
    block iteration:
      var reader: CsvParser
      reader.open(fpath)
      echo "reading " & fpath
      reader.readHeaderRow()
      if uni_key in reader.headers == false:
        break iteration
      while reader.readRow():
        var pos = table[uni_key].PosInCont(reader.rowEntry(uni_key))
        if pos >= 0:
          PositionFilter.incl(pos)
  for i in keys(table):
      var tmp_seq:seq[string]
      for pos in 0..table[i].high():
        if pos notin PositionFilter:
          tmp_seq.add(table[i][pos])
      table[i] = tmp_seq
  return

proc ExportToCsv*(table:Table[string,seq[string]],name:string)=
  var header =""
  var length:int = -1
  echo name
  for i in keys(table):
    if length < 0:
      length = table[i].len()
    elif length != table[i].len():
      echo i," ",length," " ,table[i].len()
      stderr.write("size incosistent between collumns")
      return
    header = header & i & ","
  header = header[0..<header.high()]
  var writer: File
  if writer.open(name,fmWrite) == false:
    echo "could not open file"
    return
  writer.write(header)
  for pos in 0..<length:
    var tmp: string
    tmp = ""
    for key in keys(table):
      tmp.add(table[key][pos])
      tmp.add(",")
    tmp[tmp.high()] = '\n'
    writer.write(tmp)
    tmp = ""
  return

proc DefExport*(table:Table[string,seq[string]],foldername:string,uni_key:string)=
  var folder:string = foldername
  if foldername[foldername.high()] !=  '/':
    folder.add('/')

  if existsOrCreateDir(foldername):
    var tmp_table = table
    var tmp_files:seq[string]
    for dir in walkFiles(fmt"{folder}*"):
      if DateToday() in dir.string:
        continue
      tmp_files.add(dir)
    FilterCurrent(tmp_table,tmp_files,uni_key)
    ExportToCsv(tmp_table,folder & DateToday() )
  else:
    ExportToCsv(table,folder & DateToday() )



if isMainModule:
  echo "henlo"
  #@TODO : Make test for module
