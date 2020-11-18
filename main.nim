#import xmltree
import httpClient
import htmlparser
import xmltree
import sequtils
import tables
#import strtabs

type
  TagId = object 
    XTag:string
    Prop:string
    UniqueIdentifier:string
    Value:string
    Text:string

  ContainerTag =object
    WrapperTag: TagId
    TargetTag: seq[TagId]

  SpiderDen = object
    Rootpoint:string
    Page_que:seq[string]
    Targets:ContainerTag
    Next_page:TagId

proc getnext_pages(dom:XmlNode,target_tag:TagId,root:string):seq[string]=
  var res : seq[string]
  #@TODO make it so it's a switchcase like a state machine
  for i in dom.findAll(target_tag.XTag):
    if i.innerText == target_tag.Text:
      if not(root & i.attr(target_tag.Prop) in res):
        res.add(root & i.attr(target_tag.Prop))
  return res


proc WeaveWeb(spec:var SpiderDen):seq[Table[string,string]]=
  var tmp_client = newHttpClient()
  var page_seq_swp : seq[string]
  while spec.Page_que.len() != 0:
    for crnt_page in spec.Page_que:
      var dom=parseHtml(tmp_client.getContent(crnt_page))
      page_seq_swp.add(getnext_pages(dom,spec.Next_page,spec.Rootpoint))
      for selection in dom.findAll(spec.Targets.WrapperTag.XTag):
        var pair_table:Table[string,string]
        for targets in items(spec.Targets.TargetTag):
          for subtags in selection.findAll(targets.XTag):
            #@TODO make it so it's a switchcase like a state machine
            if targets.UniqueIdentifier in subtags.attrs:
              table[]




    spec.Page_que = page_seq_swp
  return


if isMainModule == true:
  var tmp_client = newHttpClient()
  echo "is not done"
