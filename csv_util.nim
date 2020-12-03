import tables
import parsecsv
import intsets
import os
import times
import strformat

proc PosInCont[T](container:seq[T],item:T):int=
  for pos in 0..container.high():
    if container[pos] == item:
      return pos
  return -1

proc FilterCurrent*(table:var Table[string,seq[string]],files:seq[string],uni_key:string)=
  var PositionFilter:IntSet=initIntSet()
  for fpath in items(files):
    block iteration:
      var reader: CsvParser
      reader.open("temp.csv")
      reader.readHeaderRow()
      if uni_key in reader.headers == false:
        break iteration
      while reader.readRow():
        var pos = table[uni_key].PosInCont(reader.rowEntry(uni_key))
        if pos >= 0:
          PositionFilter.incl(pos)
  for i in keys(table):
      var tmp_seq:seq[string]
      for pos in 0..table[uni_key].high():
        if pos notin PositionFilter:
          tmp_seq.add(table[uni_key][pos])
      table[uni_key] = tmp_seq
  return
    
proc ExportToCsv*(table:Table[string,seq[string]],name:string)=
  var header =""
  var length:int = -1
  for i in keys(table):
    if length < 0:
      length = table[i].len()
    elif length != table[i].len():
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
  if existsOrCreateDir(foldername):
    var tmp_table = table
    var tmp_files:seq[string]
    for dir in walkFiles(fmt"{foldername}/*"):
      tmp_files.add(dir)
    FilterCurrent(tmp_table,tmp_files,uni_key)
  else:
    if foldername[foldername.high()] == '/':
      var date_fname:string = now().utc().format("dd-MM-yyyy") & ".csv" 
      ExportToCsv(table,foldername & date_fname )

if isMainModule:
  echo "henlo"
  #@TODO : Make test for module
