#import xmltree
import httpClient
import htmlparser
import xmltree
import sequtils
#import strtabs

type
  Property = object 
    xTag:string
    prop:string
    value:string
    text:string

  Group = object
    collums:seq[Property]

  TagSpec = object
    targets:seq[Group]

  SpiderDen = object
    rootpoint:string
    page_que:seq[string]
    next_page:Property

proc getnext_pages(dom:XmlNode,target_tag:Property,root:string):seq[string]=
  var res : seq[string]
  for i in dom.findAll(target_tag.xTag):
    if i.innerText == target_tag.text:
      if not(root & i.attr(target_tag.prop) in res):
        res.add(root & i.attr(target_tag.prop))
  return res


proc WeaveWeb(spec:var SpiderDen)=
  var tmp_client = newHttpClient()
  var page_seq_swp : seq[string]
  while spec.page_que.len() != 0:
    for crnt_page in spec.page_que:
      var dom=tmp_client.getContent(crnt_page)
      page_seq_swp.add(getnext_pages(dom,spec.next_page,spec.rootpoint))
      # read page
    spec.page_que = page_seq_swp
  return


if isMainModule == true:
  var tmp_client = newHttpClient()
  echo "is not done"
