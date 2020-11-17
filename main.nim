#import xmltree
import httpClient
import htmlparser
import xmltree
#import strtabs

type
  Property = object 
    xTag:string
    prop:string
    value:string

  Group = object
    collums:seq[Property]

  TagSpec = object
    targets:seq[Group]

  SpiderDen = object
    rootpoint:string
    page_que:seq[string]
    next_page:Property

proc WeaveWeb(spec:var SpiderDen)=
  var tmp_clinet = newHttpClient()
  var page_seq_swp : seq[string]
  while spec.page_que.len() != 0:
    for crnt_page in spec.page_que:
      echo crnt_page

if isMainModule == true:
  echo "is not done"
