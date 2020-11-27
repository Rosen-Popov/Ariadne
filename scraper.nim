import re
import htmlparser
import xmltree
import sets
import tables
import bitops
import strtabs
import sequtils
import strformat
import httpClient
import locks

const GetText:int =       1 shl 0
const PrepRoot:int=       1 shl 1
const UseText:int =       1 shl 2
const UseUid:int =        1 shl 3
const TextIsRegex:int=    1 shl 4
const TextIsSubstr:int=   1 shl 5
const UidIsRegex:int =    1 shl 6
const UidVIsRegex:int =   1 shl 7

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
PrcRg.mutex.initLock()

#
# @function : ComplId
#
# @args : TagId
#
# @retrun : a concatenated string from TagId.Uid and TagId.UidV
#
proc ComplId(tar:TagId):string=
  return tar.Uid & "=" & tar.UidV

#
# @operator : |
#
# @args : 2 integers
#
# @retrun : birwise or of 2 inputs
#
proc `|`(a,b:int):int=
  return bitor(a,b)
#
# @operator &
#
# @args 2 integers
#
# @retrun bitwise and of 2 inputs
#
proc `&`(a,b:int):int=
  return bitand(a,b)

#
# @operator : ?
#
# @args : 2 integers
#
# @retrun : checks if the two numbers have a bit overlap and returns it cast to bool
#
proc `?`(mask,item:int):bool=
  return bitand(mask,item).bool

#
# @function : IsTarget
#
# @brief : Checks if test_tag abides the criteria from ctlTag
#
# @args test_tag : XmlNode
# @args ctlTag   : TagId
#
# @retrun : checks id XmlNode matches the criterai of a provided TagId
#
proc IsTarget(test_tag:XmlNode,ctlTag:TagId):bool=
  var Filter:bool = true
  if ctlTag.Flags ? UseText:
    case ctlTag.Flags & (TextIsRegex | TextIsSubstr):
      of TextIsRegex | TextIsSubstr:
        stderr.write("Text cant be either substring or a regex")
        assert(false)
      of TextIsRegex:
        Filter = Filter and match(test_tag.innerText,PrcRg.table[ctlTag.Text])
      of TextIsSubstr:
        Filter = Filter and (find(test_tag.innerText,PrcRg.table[ctlTag.Text]) > 0)
      else:
        Filter = Filter and test_tag.innerText == ctlTag.Text
  block UidUidVMatchPair:
    if (ctlTag.Flags ? UseUid) and Filter:
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

#
# @function : SmartPrep
#
# @brief : Prepends uri to text minding the '/'
#
# @args Uri  : string
# @args text : string
#
# @retrun : Prepends Uri to text t omake it a viable uri
#
proc SmartPrep(Uri,text:string):string=
  if text[0] == '/' and Uri[Uri.high()] == '/':
    return Uri[0..<Uri.high()] & text
  elif text[0] != '/' and Uri[Uri.high()] != '/':
    return Uri & "/" & text
  elif text[0] != '/' and Uri[Uri.high()] == '/':
    return Uri & text
#
# @function : getnext_pages
#
# @breif search all tags bellow the dom and find all tags that fit the target tag
#
# @args dom : XmlNode -> node which we recursively search
# @args target_tag : TagId -> target tag for filtering
# @args root : string  -> root link
# @args store : var HashSet[string]) -> hashset that stores pages visited
#
proc getnext_pages(dom:XmlNode,target_tag:TagId,root:string,store:var HashSet[string])=
  for i in dom.findAll(target_tag.XTag):
    if i.IsTarget(target_tag):
      if target_tag.Flags ? PrepRoot:
        store.incl(SmartPrep(root, i.attr(target_tag.Prop)))
      else:
        store.incl(i.attr(target_tag.Prop))
  return

#
# @function PrecompileRegexes
#
# @brief : Precompiles regexes for later use
#
# @args targets : seq[TagId]
#
proc PrecompileRegexes(targets:seq[TagId])=
  PrcRg.mutex.acquire()
  for i in items(targets):
    if (i.Flags & TextIsRegex).bool and not (i.Text in PrcRg.table):
      PrcRg.table[i.Text] = re(i.Text)
    if (i.Flags & UidIsRegex).bool and not (i.Uid in PrcRg.table):
      PrcRg.table[i.Uid] = re(i.Uid)
    if (i.Flags & TextIsRegex).bool and not (i.UidV in PrcRg.table):
      PrcRg.table[i.UidV] = re(i.UidV)

  PrcRg.mutex.release()
  return

#
# @function : WeaveWeb
#
# @brief : searches with the provided SpiderDen
#
# @args spec:  SpiderDen
#
# @retrun : information gathered 
#
proc WeaveWeb*(spec:var SpiderDen):Table[string,seq[string]]=
  var tmp_client = newHttpClient()
  var newPages : HashSet[string]
  var Storage:Table[string,seq[string]]
  var visited:HashSet[string]
  var sanity_check:int = -1
  var sanity_key: string
  var page:int = 0
  PrecompileRegexes(concat(spec.Targets,@[spec.NextPage]))

  for i in spec.Targets:
    Storage[i.ComplId()] = @[]
    if i.Flags ? GetText:
      Storage[i.ComplId() & "_Text"] = @[]

  block Ariadne:
    while spec.PageQue.len() != 0:
      for crnt_page in items(spec.PageQue):
        echo "crnt page " & crnt_page
        var dom=parseHtml(tmp_client.getContent(crnt_page))
        getnext_pages(dom,spec.NextPage,spec.Rootpoint,newPages)
        for targets in spec.Targets:
          for selection in dom.findAll(targets.Xtag):
            if selection.IsTarget(targets):
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
  #@TODO : Add some tests
  echo "henlo"

