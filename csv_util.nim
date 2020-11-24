import tables
import parsecsv
import intsets
proc PosInCont[T](container:seq[T],item:T):int=
  for pos in 0..container.high():
    if container[pos] == item:
      return pos
  return -1

proc FilterCurrent(table:var Table[string,seq[string]],files:seq[string],uni_key:string)=
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




if isMainModule:
  echo "henlo"
