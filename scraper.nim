import httpClient
import htmlparser
import xmltree
import sets
import tables
import bitops

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
    Page_que:HashSet[string]
    Targets:seq[TagId]
    Next_page:TagId

proc getnext_pages(dom:XmlNode,target_tag:TagId,root:string):HashSet[string]=
  var res : HashSet[string]
  #@TODO : Make it so it's a switchcase like a state machine
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

proc WeaveWeb(spec:var SpiderDen):Table[string,seq[string]]=
  var tmp_client = newHttpClient()
  var newPages : HashSet[string]
  var Storage:Table[string,seq[string]]
  var visited:HashSet[string]
  for i in spec.Targets:
    Storage[i.ComplId()] = @[]
    if i.Flags ? GetText:
      Storage[i.ComplId() & "_Text"] = @[]

  while spec.Page_que.len() != 0:
    for crnt_page in items(spec.Page_que):
      echo "crnt page " & crnt_page
      var dom=parseHtml(tmp_client.getContent(crnt_page))
      newPages.incl(getnext_pages(dom,spec.Next_page,spec.Rootpoint))
      for targets in spec.Targets:
        for selection in dom.findAll(targets.Xtag):
          if selection.attr(targets.Uid) == targets.UidV and selection.attr(targets.Prop) != "":
            if targets.Flags ? PrepRoot:
              Storage[targets.ComplId() ].add(SmartPrep(spec.RootPoint,selection.attr(targets.Prop)))
            else:
              Storage[targets.ComplId() ].add(selection.attr(targets.Prop))
            if targets.Flags ? GetText:
              Storage[targets.ComplId() & "_Text"].add(selection.innerText())

    spec.Page_que = newPages.difference(visited)
    visited.incl(newPages)
  return Storage

if isMainModule == true:
  #@TODO : Add Tests
  echo "Compiled Correctly"

