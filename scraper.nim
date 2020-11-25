import httpClient
import htmlparser
import xmltree
import sets
import tables
import bitops
import strformat

let GetText:int = 1
let PrepRoot:int = 2

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

proc getnext_pages(dom:XmlNode,target_tag:TagId,root:string):HashSet[string]=
  var res : HashSet[string]
  #@TODO : Make it so it's a switchcase or more flexible
  for i in dom.findAll(target_tag.XTag):
    if i.innerText == target_tag.Text:
      res.incl(root & i.attr(target_tag.Prop))
  return res

proc ComplId(tar:TagId):string=
  return tar.Uid & "=" & tar.UidV

proc `|`(a,b:int):int=
  return bitor(a,b)

proc `&`(a,b:int):int=
  return bitand(a,b)

proc `?`(mask,item:int):bool=
  return bitand(mask,item).bool

proc SmartPrep(Uri,text:string):string=
  if text[0] == '/' and Uri[Uri.high()] == '/':
    return Uri[0..<Uri.high()] & text
  elif text[0] != '/' and Uri[Uri.high()] != '/':
    return Uri & "/" & text
  elif text[0] != '/' and Uri[Uri.high()] == '/':
    return Uri & text

proc WeaveWeb*(spec:var SpiderDen):Table[string,seq[string]]=
  var tmp_client = newHttpClient()
  var newPages : HashSet[string]
  var Storage:Table[string,seq[string]]
  var visited:HashSet[string]
  var sanity_check:int = -1
  var sanity_key: string
  var page:int = 0

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

