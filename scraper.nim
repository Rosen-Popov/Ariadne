import re
import htmlparser
import xmltree
import sets
import tables
import bitops
import strtabs
import strformat
import httpClient
import locks

const GetText:int =       1 shl 0
const PrepRoot:int=       1 shl 1
const UseText:int =       1 shl 2
const UseUid:int =        1 shl 3
const TextIsRegex:int=    1 shl 4
const UidIsRegex:int =    1 shl 5
const UidVIsRegex:int =   1 shl 6


type
  TagId = object
    XTag:string
    Uid:string
    UidV:string
    Prop:string
    Value:string
    Text:string
    Flags:int

  SpiderDen = object
    Rootpoint:string
    PageQue:HashSet[string]
    Targets:seq[TagId]
    NextPage:TagId
    FailNonEqu:bool
    PageLimit:int

  ThrSafeGlRegexTable =object
    #@TODO make functions to deal with that
    mutex:Lock
    table:Table[string,Regex]

var PrcRg:ThrSafeGlRegexTable

proc ComplId(tar:TagId):string=
  return tar.Uid & "=" & tar.UidV

proc `|`(a,b:int):int=
  return bitor(a,b)

proc `&`(a,b:int):int=
  return bitand(a,b)

proc `?`(mask,item:int):bool=
  return bitand(mask,item).bool

#@TODO :Make documentation
proc Elegiable(test_tag:XmlNode,ctlTag:TagId):bool=
  var Filter:bool = true
  if ctlTag.Flags ? UseText:
    if ctlTag.Flags ? TextIsRegex:
      Filter = Filter and
      match(test_tag.innerText,PrcRg.table[ctlTag.Text])
    else:
      Filter = Filter and test_tag.innerText == ctlTag.Text
  block UidUidVMatchPair:
    if (ctlTag.Flags ? UseUid) and Filter == true:
      case ctlTag.Flags & (UidVIsRegex | UidIsRegex):
        of UidVIsRegex | UidIsRegex:
          for prop in test_tag.attrs().keys():
            if match(prop,PrcRg.table[ctlTag.Uid]) and match(test_tag.attr(prop), PrcRg.table[ctlTag.UidV]):
              Filter = true
              break UidUidVMatchPair
          Filter = false
        of UidIsRegex:
          for prop in test_tag.attrs().keys():
            if match(prop,PrcRg.table[ctlTag.Uid]) and test_tag.attr(prop) == ctlTag.UidV:
              Filter = true
              break UidUidVMatchPair
          Filter = false
        of UidVIsRegex:
          Filter = Filter and match(test_tag.attr(ctlTag.Uid),PrcRg.table[ctlTag.UidV])
        else :
          Filter = Filter and test_tag.attr(ctlTag.Uid) == ctlTag.UidV
  return Filter

#@TODO :Make documentation
proc getnext_pages(dom:XmlNode,target_tag:TagId,root:string):HashSet[string]=
  # @TODO make it os it uses the same hashset
  var res : HashSet[string]
  for i in dom.findAll(target_tag.XTag):
    if i.Elegiable(target_tag):
      res.incl(root & i.attr(target_tag.Prop))
  return res

#@TODO :Make documentation
proc SmartPrep(Uri,text:string):string=
  if text[0] == '/' and Uri[Uri.high()] == '/':
    return Uri[0..<Uri.high()] & text
  elif text[0] != '/' and Uri[Uri.high()] != '/':
    return Uri & "/" & text
  elif text[0] != '/' and Uri[Uri.high()] == '/':
    return Uri & text

#@TODO :Make documentation
proc PrecompileRegexes(nextpage:TagId,targets:seq[TagId])=
  #@TODO precompile regexes
  return

#@TODO :Make documentation
proc WeaveWeb*(spec:var SpiderDen):Table[string,seq[string]]=
  var tmp_client = newHttpClient()
  var newPages : HashSet[string]
  var Storage:Table[string,seq[string]]
  var visited:HashSet[string]
  var sanity_check:int = -1
  var sanity_key: string
  var page:int = 0
  PrecompileRegexes(spec.NextPage,spec.Targets)

  for i in spec.Targets:
    Storage[i.ComplId()] = @[]
    if i.Flags ? GetText:
      Storage[i.ComplId() & "_Text"] = @[]

  block Ariadne:
    while spec.PageQue.len() != 0:
      for crnt_page in items(spec.PageQue):
        echo "crnt page " & crnt_page
        var dom=parseHtml(tmp_client.getContent(crnt_page))
        newPages.incl(getnext_pages(dom,spec.NextPage,spec.Rootpoint))
        for targets in spec.Targets:
          for selection in dom.findAll(targets.Xtag):
            #@TODO make this use Elegiable
            if selection.attr(targets.Uid) == targets.UidV and selection.attr(targets.Prop) != "":
              if targets.Flags ? PrepRoot:
                Storage[targets.ComplId() ].add(SmartPrep(spec.RootPoint,selection.attr(targets.Prop)))
              else:
                Storage[targets.ComplId() ].add(selection.attr(targets.Prop))
              if targets.Flags ? GetText:
                Storage[targets.ComplId() & "_Text"].add(selection.innerText())
        page = page + 1
        if spec.PageLimit>0 and page > spec.PageLimit :
          break Ariadne

      spec.PageQue = newPages.difference(visited)
      visited.incl(newPages)

  for p in keys(Storage):
    if sanity_check < 0:
      sanity_key = p
      sanity_check = Storage[p].len()
    elif Storage[p].len() != sanity_check:
      stderr.write(fmt"Length mismatch between {sanity_key}:size({sanity_check}) and {p}:size({Storage[p].len()})")
      if spec.FailNonEqu == true:
        Storage.clear()
  return Storage

if isMainModule == true:
  #@TODO : Add Tests
  echo "henlo"

