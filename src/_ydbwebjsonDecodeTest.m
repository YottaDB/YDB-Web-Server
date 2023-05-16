%ydbwebjsonDecodeTest ;SLC/KCM -- Unit tests for JSON decoding;2019-07-16  2:17 PM
	;
	do en^%ut($text(+0),3)
	quit
	;
jsonues ;; @TEST unescape JSON encoded string
	new x
	set x=$$ues^%ydbwebjson("String with \\ in the middle")
	do eq^%ut("String with \ in the middle",x)
	set x=$$ues^%ydbwebjson("\\ is the first character of this string")
	do eq^%ut("\ is the first character of this string",x)
	set x=$$ues^%ydbwebjson("The last character of this string is \\")
	do eq^%ut("The last character of this string is \",x)
	set x=$$ues^%ydbwebjson("\\one\\two\\three\\")
	do eq^%ut("\one\two\three\",x)
	set x=$$ues^%ydbwebjson("A vee shape: \\\/\tTABBED\tand line endings.\n\r\f")
	do eq^%ut("A vee shape: \/"_$char(9)_"TABBED"_$char(9)_"and line endings."_$char(10,13,12),x)
	set x=$$ues^%ydbwebjson("\""This text is quoted\""")
	do eq^%ut("""This text is quoted""",x)
	set x=$$ues^%ydbwebjson("This text contains an embedded\u001A control character")
	do eq^%ut("This text contains an embedded"_$char(26)_" control character",x)
	set x=$$ues^%ydbwebjson("This contains tab\t and control\u0016 characters")
	do eq^%ut("This contains tab"_$char(9)_" and control"_$char(22)_" characters",x)
	quit
	;
splita ;; @TEST JSON input with escaped characters on single line (uses build)
	new json,y,err,esc
	; V4W/DLW - Removed "string" from SPLIT+3^%ydbwebjsonTestData1
	set esc="this contains \and other escaped characters such as "_$char(10)
	; V4W/DLW - Removed "a piece of" from SPLIT+5^%ydbwebjsonTestData1
	set esc=esc_"  and a few tabs "_$char(9,9,9,9)_" and ""quoted text"""
	do build("split",.json)
	do eq^%ut(0,$data(json(2)))
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(esc,$get(y("esc")))
	do eq^%ut("this is a new line",$get(y("next")))
	do eq^%ut("this is a string that goes across two lines",$get(y("wp")))
	do eq^%ut("here is another string",$get(y("nextLineQuote")))
	quit
splitb ;; @TEST multiple line JSON input with lines split across tokens (uses builda)
	new json,y,err,esc
	; V4W/DLW - Removed "string" from SPLIT+3^%ydbwebjsonTestData1
	set esc="this contains \and other escaped characters such as "_$char(10)
	; V4W/DLW - Removed "a piece of" from SPLIT+5^%ydbwebjsonTestData1
	set esc=esc_"  and a few tabs "_$char(9,9,9,9)_" and ""quoted text"""
	do builda("split",.json)
	do eq^%ut(1,$data(json(2)))
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(esc,$get(y("esc")))
	do eq^%ut("this is a new line",$get(y("next")))
	do eq^%ut("this is a string that goes across two lines",$get(y("wp")))
	do eq^%ut("here is another string",$get(y("nextLineQuote")))
	quit
splitc ;; @TEST multiple line JSON input with lines split inside boolean value
	new json,y,err,esc
	do builda("splitc",.json)
	do eq^%ut(1,$data(json(4)))
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("false",$get(y("completed")))
	do eq^%ut("urn:va:user:2C0A:1134",$get(y("ownerCode")))
	do eq^%ut("SQA,ONE",$get(y("assignToName")))
	do eq^%ut("urn:va:user:2C0A:1134",$get(y("assignToCode")))
	quit
splitd ;; @TEST multiple line JSON input with key split
	new json,y,err
	set json(1)="{ ""boo"": ""foo"", ""code"" : ""22-2""}"
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(y("code"),"22-2")
	new json,y,err
	set json(1)="{ ""boo"": ""foo"", ""c"
	set json(2)="ode"": ""22-2""}"
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(y("code"),"22-2")
	quit
	;
long ;; @TEST long document that must be saved across extension nodes
	new json,y,err,i,line,ccnt1,ccnt2
	set json(1)="{""title"":""long document"",""size"":""rather large"",""document"":"""
	set line="This is a line of text intended to test longer documents.\r\n  It will be repeated so that there are several nodes that must be longer than 4000 kilobytes."
	for i=2:1:100 set json(i)=line
	set json(101)="\r\nThis line ends with a control character split over to the next line.\u0"
	set json(102)="016The last line has a control character.\u001A"
	set json(103)=""",""author"":""WINDED,LONG""}"
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	set ccnt1=0 for i=2:1:102  set ccnt1=ccnt1+$length(json(i))
	set ccnt2=$length(y("document")) for i=1:1:199 set ccnt2=ccnt2+$length(y("document","\",i))
	do eq^%ut(210,ccnt1-ccnt2) ; 100 \r\n->$char(13,10), 1 \u001a->$char(26), 1 \u0016->$char(22) = 210 less chars
	do eq^%ut(59,$length(y("document")))
	do eq^%ut(94,$length(y("document","\",3)))
	do eq^%ut(1,y("document","\",198)[$char(22))
	do eq^%ut($char(26),$extract(y("document","\",199),$length(y("document","\",199))))
	do eq^%ut(0,$data(y("document",4)))
	do eq^%ut("WINDED,LONG",y("author"))
	do eq^%ut("rather large",y("size"))
	quit
frac ;; @TEST multiple lines with fractional array elements
	;; {"title":"my array of stuff", "count":3, "items": [
	;; {"name":"red", "rating":"ok"},
	;; {"name":"blue", "rating":"good"},
	;; {"name":"purple", "rating":"outstanding"}
	;; ]}
	new json,y,err
	set json(0)=$zpiece($text(frac+1),";;",2,99)
	set json(.5)=$zpiece($text(frac+2),";;",2,99)
	set json(1)=$zpiece($text(frac+3),";;",2,99)
	set json(1.1)=$zpiece($text(frac+4),";;",2,99)
	set json(1.2)=$zpiece($text(frac+5),";;",2,99)
	set json("JUNK")="Junk non-numeric node -- this should be ignored"
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("purple",y("items",3,"name"))
	quit
valonly ;; @TEST passing in value only -- not array
	new json,y,err
	set json=$zpiece($text(valonly+1^%ydbwebjsonTestData1),";;",2,999)
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("urn:va:param:F484:1120:VPR USER PREF:1120",y("uid"))
	do eq^%ut("north",y("vals","cpe.patientpicker.loc"))
	quit
numeric ;; @TEST passing in numeric types and strings
	new json,y,err
	set json=$zpiece($text(numeric+1^%ydbwebjsonTestData1),";;",2,999)
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(234567,+y("count")) ; make sure it's numeric
	do eq^%ut(20120919,y("hl7Time"))
	do eq^%ut(1,$data(y("hl7Time","\s")))
	do eq^%ut("722.10",y("icd"))
	do eq^%ut(0,+y("icd")="722.10") ; make sure it's a string
	quit
nearzero ;; @TEST decoding numbers near 0
	;; {"x":0.42, "y":-0.44, "s":"0.5", "t":"-0.6"}
	new json,y,err
	set json=$zpiece($text(nearzero+1),";;",2,999)
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(1,$data(y("x","\n")))
	do eq^%ut(1,$data(y("y","\n")))
	do eq^%ut(.42,y("x"))
	do eq^%ut(-.44,y("y"))
	do eq^%ut(0,y("s")=.5)
	do eq^%ut(0,y("t")=-.6)
	quit
badquote ;; @TEST poorly formed JSON (missing close quote on LABEL)
	new json,y,err
	do build("badquote",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(1,$data(err)>0)
	quit
badslash ;; @TEST poorly formed JSON (non-escaped backslash)
	new json,y,err
	do build("badslash",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(1,$data(err)>0)
	quit
badbrace ;; @TEST poorly formed JSON (Extra Brace)
	new json,y,err
	do build("badbrace",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(1,$data(err)>0)
	quit
badcomma ;; @TEST poorly formed JSON (Extra Comma)
	new json,y,err
	do build("badcomma",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(1,$data(err)>0)
	quit
psnum ;; @TEST subjects that look like a numbers shouldn't be encoded as numbers
	new json,y,err
	do build("psnum",.json)
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(y("0.85,0.01","AUDIT"),"TEST1")
	do eq^%ut(y("0.85,0.02","AUDIT"),"TEST3")
	do eq^%ut(y("0.85,0.03","AUDIT"),"TEST5")
	quit
numlabel ;; @TEST label that begins with numeric
	new json,y,err
	do build("numlabel",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(46570,y("syncStatusByVistaSystemId","9E99","dfn"))
	quit
purenum ;; @TEST label that is purely numeric
	new json1,json2,y,RSLT,err
	do build("purenum1",.json1)
	do decode^%ydbwebjson("json1","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(100,y("syncStatusByVistaSystemId","""1234","domainExpectedTotals","bar","total"))
	do eq^%ut(1,$data(y("forOperational","\s"))) ; appears boolean but really a string
	do encode^%ydbwebjson("y","json2","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(1,($length(json1(1))=($length(json2(1))+$length(json2(2))+$length(json2(3)))))
	do eq^%ut(1,(json2(2)[":{""1234"":{"))
	do build("purenum2",.RSLT)
	do eq^%ut(RSLT(1),json2(1)_json2(2)_json2(3))
	quit
strtypes ;; @TEST strings that may be confused with other types
	new json,y,err
	do build("strtypes",.json)
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(1,$data(y("syncStatusByVistaSystemId","""1234","syncComplete","\s")))
	quit
estring ;; @TEST a value that looks like an exponents, other numerics
	new json,y,json2,err
	do build("estring",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("32E497ABC",y("b"))
	do eq^%ut(.123,y("c"))
	do eq^%ut(3E22,y("g"))
	do eq^%ut(1,$data(y("g","\n")))
	do eq^%ut(0,y("h")=2E8)
	do encode^%ydbwebjson("y","json2","err")
	do eq^%ut(1,json(1)=(json2(1)_json2(2)))
	quit
sam1 ;; @TEST decode sample 1 from JSON.ORG
	new json,y,err
	do build("sam1",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("file",$get(y("menu","id")))
	do eq^%ut("OpenDoc()",$get(y("menu","popup","menuitem",2,"onclick")))
	quit
sam2 ;; @TEST decode sample 2 from JSON.ORG
	new json,y,err
	do build("sam2",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("XML",$get(y("glossary","GlossDiv","GlossList","GlossEntry","GlossDef","GlossSeeAlso",2)))
	do eq^%ut("SGML",$get(y("glossary","GlossDiv","GlossList","GlossEntry","SortAs")))
	quit
sam3 ;; @TEST decode sample 3 from JSON.ORG
	new json,y,err
	do build("sam3",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(500,$get(y("widget","window","width")))
	do eq^%ut("sun1.opacity = (sun1.opacity / 100) * 90;",$get(y("widget","text","onMouseUp")))
	do eq^%ut("Sample Konfabulator Widget",$get(y("widget","window","title")))
	quit
sam4 ;; @TEST decode sample 4 from JSON.ORG
	new json,y,err
	do build("sam4",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(0,$data(y("web-app","servlet",6)))  ; should only be 5 servlets
	do eq^%ut(1,$get(y("web-app","servlet",5,"init-param","log")))
	do eq^%ut("/usr/local/tomcat/logs/CofaxTools.log",$get(y("web-app","servlet",5,"init-param","logLocation")))
	do eq^%ut("/",$get(y("web-app","servlet-mapping","cofaxCDS")))
	do eq^%ut("/WEB-INF/tlds/cofax.tld",$get(y("web-app","taglib","taglib-location")))
	quit
sam5 ;; @TEST decode sample 5 from JSON.ORG
	new json,y,err
	do build("sam5",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(0,$data(y("menu","items",23)))  ; should only be 22 items
	do eq^%ut("About Adobe CVG Viewer...",$get(y("menu","items",22,"label")))
	do eq^%ut("null",$get(y("menu","items",3)))
	quit
	;
maxnum ;; @TEST encode large string that looks like number
	new i,x,y,json,err,out
	for i=0:1 set x=$zpiece($text(maxnum+(i+1)^%ydbwebjsonTestData1),";;",2,999) quit:x="#####"  set json(i)=x
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(217,$length(y("taskName","\",1)))
	do encode^%ydbwebjson("y","out","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(1,$length(out(1))=93)
	do eq^%ut(1,out(3)["""facilityCode"":""500")
	quit
escq ;; @TEST escaped quote across lines
	new json,y,err
	do builda("escq",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(55,$length(y("comments")))
	kill json,y,err
	do builda("escq2",.json) do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut(42,$length(y("bjw")))
	quit
keyquote ;; @TEST keys with quotes
	new encode,json,y,err
	set json="{""a(1,3:\""\"")"":""AREG""}"
	do decode^%ydbwebjson("json","y","err")
	do eq^%ut(0,$data(err))
	do eq^%ut("AREG",$get(y("a(1,3:"""")")))
	kill err
	do encode^%ydbwebjson("y","encode","err")
	do eq^%ut(encode(1),json)
	quit
build(tag,json) ; Build array of strings in JSON for tag
	new x,i,line
	set line=1,json(line)=""
	for i=1:1 set x=$extract($text(@tag+i^%ydbwebjsonTestData1),4,999) quit:x="#####"  D
	. if $length(json(line))+$length(x)>4000 set line=line+1,json(line)=""
	. set json(line)=json(line)_x
	quit
builda(tag,json) ; Build array of string in JSON with splits preserved
	new x,i
	for i=1:1 set x=$extract($text(@tag+i^%ydbwebjsonTestData1),4,999) quit:x="#####"  set json(i)=x
	quit
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright 2016 Accenture Federal Services
	; Copyright 2013-2019 Sam Habiel
	; Copyright (c) 2022-2023 YottaDB LLC
	;
	;Licensed under the Apache License, Version 2.0 (the "License");
	;you may not use this file except in compliance with the License.
	;You may obtain a copy of the License at
	;
	;    http://www.apache.org/licenses/LICENSE-2.0
	;
	;Unless required by applicable law or agreed to in writing, software
	;distributed under the License is distributed on an "AS IS" BASIS,
	;WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	;See the License for the specific language governing permissions and
	;limitations under the License.

