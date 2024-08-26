%ydbwebjsonEncodeTest ;SLC/KCM -- Unit tests for JSON encoding;2019-11-14  9:08 AM
	do en^%ut($text(+0),3)
	quit
	;
numeric ;; @TEST is numeric function
	do eq^%ut(0,$$numeric^%ydbwebjsonEncode("2COWS"))
	do eq^%ut(0,$$numeric^%ydbwebjsonEncode("007"))
	do eq^%ut(0,$$numeric^%ydbwebjsonEncode(".4"))
	do eq^%ut(1,$$numeric^%ydbwebjsonEncode("0.4"))
	do eq^%ut(0,$$numeric^%ydbwebjsonEncode("-.4"))
	do eq^%ut(1,$$numeric^%ydbwebjsonEncode("-0.4"))
	do eq^%ut(1,$$numeric^%ydbwebjsonEncode(0))
	do eq^%ut(0,$$numeric^%ydbwebjsonEncode(".0"))
	do eq^%ut(1,$$numeric^%ydbwebjsonEncode(3.1416))
	do eq^%ut(1,$$numeric^%ydbwebjsonEncode("2.3E-2"))
	do eq^%ut(1,$$numeric^%ydbwebjsonEncode(0.4E12))
	do eq^%ut(0,$$numeric^%ydbwebjsonEncode(".4E-12"))
	quit
nearzero ;; @TEST encode of numbers near 0
	;;{"s":"0.5","t":"-0.6","x":0.42,"y":-0.44}
	new x,json,err
	set x("s")="0.5",x("s","\s")=""
	set x("t")="-0.6",x("t","\s")=""
	set x("x")=0.42
	set x("y")=-0.44
	do encode^%ydbwebjson("x","json","err")
	do eq^%ut($zpiece($text(nearzero+1),";;",2,99),json(1))
	quit
jsonesc ;; @TEST create JSON escaped string
	new x
	set x=$$esc^%ydbwebjson("String with \ in the middle")
	do eq^%ut("String with \\ in the middle",x)
	set x=$$esc^%ydbwebjson("\ is the first character of this string")
	do eq^%ut("\\ is the first character of this string",x)
	set x=$$esc^%ydbwebjson("The last character of this string is \")
	do eq^%ut("The last character of this string is \\",x)
	set x=$$esc^%ydbwebjson("\one\two\three\")
	do eq^%ut("\\one\\two\\three\\",x)
	set x=$$esc^%ydbwebjson("A vee shape: \/"_$char(9)_"TABBED"_$char(9)_"and line endings."_$char(10,13,12))
	do eq^%ut("A vee shape: \\\/\tTABBED\tand line endings.\n\r\f",x)
	set x=$$esc^%ydbwebjson("""This text is quoted""")
	do eq^%ut("\""This text is quoted\""",x)
	set x=$$esc^%ydbwebjson("This text contains an embedded"_$char(26)_" control character")
	do eq^%ut("This text contains an embedded\u001A control character",x)
	set x=$$esc^%ydbwebjson("This contains tab"_$char(9)_" and control"_$char(22)_" characters")
	do eq^%ut("This contains tab\t and control\u0016 characters",x)
	set x=$$esc^%ydbwebjson("This has embedded NUL"_$char(0)_" character.")
	do eq^%ut("This has embedded NUL\u0000 character.",x)
	quit
basic ;; @TEST encode basic object as JSON
	new x,json
	set x("myObj","booleanT")="true"
	set x("myObj","booleanF")="false"
	set x("myObj","numeric")=3.1416
	set x("myObj","nullValue")="null"
	set x("myObj","array",1)="one"
	set x("myObj","array",2)="two"
	set x("myObj","array",3)="three"
	set x("myObj","subObject","fieldA")="hello"
	set x("myObj","subObject","fieldB")="world"
	do encode^%ydbwebjson("x","json")
	do eq^%ut($$target("basic"),json(1)_json(2))
	quit
vals ;; @TEST encode simple values only object as JSON
	new x,json
	set x("prop1")="property1"
	set x("bool1")="true"
	set x("num1")="2.1e3",x("num1","\n")=""
	set x("arr",1)="apple"
	set x("arr",2)="orange"
	set x("arr",3)="pear"
	set x("arr",4,"obj")="4th array item is object"
	do encode^%ydbwebjson("x","json")
	do eq^%ut($$target("vals"),json(1)_json(2))
	quit
long ;; @TEST encode object with continuation nodes for value
	new x,i,json,filler,target
	set filler=", this will extend the line out to at least 78 characters."_$char(10)
	set x("title")="My note test title"
	set x("note")="This is the first line of the note.  Here are ""quotes"" and a \ and a /."_$char(10)
	for i=1:1:60 set x("note","\",i)="Additional Line #"_i_filler
	do encode^%ydbwebjson("x","json")
	set target=$$target("long")
	do eq^%ut(target,$extract(json(1)_json(2)_json(3),1,$length(target)))
	do eq^%ut(1,$data(json(62)))
	do eq^%ut(0,$data(json(63)))
	set target="t least 78 characters.\n"",""title"":"
	do eq^%ut(target,$extract(json(61),$length(json(61))-$length(target)+1,$length(json(61))))
	quit
pre ;; @TEST encode object where parts are already JSON encoded
	new x,json,target
	set x("count")=3
	set x("menu",1,":",1)=$$target("nodes",1)
	set x("menu",2,":",1)=$$target("nodes",2)
	set x("menu",3,":",1)=$$target("nodes",3)
	set x("template",":")=$$target("nodes",4)
	do encode^%ydbwebjson("x","json")
	set target=$$target("pre",1)_$$target("pre",2)
	do eq^%ut(target,json(1)_json(2)_json(3))
	quit
wp ;; @TEST word processing nodes inside object
	new y,json,target,err
	do buildy("wp")
	do encode^%ydbwebjson("y","json","err")
	do eq^%ut(0,$data(err))
	set target=$$target("wpout")_$$target("wpout",2)_$$target("wpout",3)
	do eq^%ut(target,json(1)_json(2)_json(3)_json(4)_json(5)_json(6)_json(7))
	quit
ltzero ;; @TEST leading / trailing zeros get preserved
	new y,json,target
	set y("count")=737
	set y("ssn")="000427930"
	set y("icd")="626.00"
	set y("price")=".65" ;M still treats this as a number, so in json it's 0.65
	set y("code")=".77",y("code","\s")=""
	set y("errors")=0
	do encode^%ydbwebjson("y","json")
	do eq^%ut($$target("ltzero"),json(1))
	quit
strings ;; @TEST force encoding as string
	new y,json,target,err
	set y("count")=234567
	set y("hl7Time")="20120919"
	set y("hl7Time","\s")=""
	set y("icd")="722.10"
	set y("name")="Duck,Donald"
	do encode^%ydbwebjson("y","json","err")
	do eq^%ut(0,$data(err))
	do eq^%ut($$target("strings"),json(1))
	quit
labels ;; @TEST unusual labels
	;;{"top":[{"10":"number 10",",":"comma",":":"colon","\\":"backslash","a":"normal letter"}]}
	;
	; NOTE: we don't allow a label to contain a quote (")
	new y,json,err
	set y("top",1,":")="colon"
	set y("top",1,"\")="backslash"
	set y("top",1,",")="comma"
	set y("top",1,"a")="normal letter"
	set y("top",1,"""10")="number 10"
	do encode^%ydbwebjson("y","json","err")
	do eq^%ut(0,$data(err))
	do eq^%ut($zpiece($text(labels+1),";;",2,99),json(1))
	quit
example ;; @TEST encode samples that are on JSON.ORG
	new y,json,target
	do buildy("ex1in")
	do encode^%ydbwebjson("y","json")
	set target=$$target("ex1out")
	do eq^%ut(target,json(1)_json(2))
	do buildy("ex2in")
	do encode^%ydbwebjson("y","json")
	set target=$$target("ex2out")_$$target("ex2out",2)
	do eq^%ut(target,json(1)_json(2)_json(3)_json(4)_json(5))
	do buildy("ex3in")
	do encode^%ydbwebjson("y","json")
	set target=$$target("ex3out")_$$target("ex3out",2)
	do eq^%ut(target,json(1)_json(2)_json(3)_json(4))
	do buildy("ex4in")
	do encode^%ydbwebjson("y","json")
	set target=$$target("ex4out")
	do eq^%ut(target,$extract(json(1)_json(2)_json(3),1,215))
	do eq^%ut(95,$length(json(1)))
	quit
keyesc ;; @TEST keys should be escaped
	new y,json,target
	set y("names","x(834038,""237745"":""240474"")")="AREG"
	do encode^%ydbwebjson("y","json")
	do eq^%ut(json(1),"{""names"":{""x(834038,\""237745\"":\""240474\"")"":""AREG""}}")
	quit
extarray ;; @TEST No top object; first level is an array
	; Bug reported by Winfried on comp.lang.mumps
	new t,t2
	set t="[{""s"":1,""n"":123},{""N1"":true,""N2"":""true""}]"
	do decode^%ydbwebjsonDecode("t","json","jerr")
	do eq^%ut($data(jerr),0)
	kill jerr
	do encode^%ydbwebjsonEncode("json","t2","jerr")
	do eq^%ut($data(jerr),0)
	do eq^%ut(t2(1),"[{""n"":123,""s"":1},{""N1"":true,""N2"":""true""}]")
	quit
	;
charzeroone ;; @TEST $char(0)/$char(1) should be encoded; decode should reverse
	; Previously $char(0) was removed, $char(1) was sent out as is
	new c for c=0,1 do
	. new x,y,json,oringal,jerr
	. set x(1)="foo"_$char(c)_"coo"
	. set x(2)=$char(c)
	. set x(3)=$char(c,c,c,c,c,c)
	. set x(4)="boo"_$char(c)
	. set x(5)=$char(c)_"a"
	. do encode^%ydbwebjson("x","json","jerr")
	. do eq^%ut($data(jerr),0)
	. if c=0 do eq^%ut(json(1),"[""foo\u0000coo"",""\u0000"",""\u0000\u0000\u0000\u0000\u0000\u0000"",""boo\u0000"",""\u0000a""]")
	. if c=1 do eq^%ut(json(1),"[""foo\u0001coo"",""\u0001"",""\u0001\u0001\u0001\u0001\u0001\u0001"",""boo\u0001"",""\u0001a""]")
	. do decode^%ydbwebjson("json","y","jerr")
	. do eq^%ut($data(jerr),0)
	. do eq^%ut(x(1),y(1))
	. do eq^%ut(x(2),y(2))
	. do eq^%ut(x(3),y(3))
	. do eq^%ut(x(4),y(4))
	. do eq^%ut(x(5),y(5))
	quit
	;
buildy(label) ; build y array based on label
	; expects y from EXAMPLE
	new i,x
	kill y
	for i=1:1 set x=$zpiece($text(@label+i^%ydbwebjsonTestData2),";;",2,999) quit:x="zzzzz"  xecute "S "_x
	quit
target(id,offset) ; values to test against
	set offset=$get(offset,1)
	quit $zpiece($text(@id+offset^%ydbwebjsonTestData2),";;",2,999)
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright 2016 Accenture Federal Services
	; Copyright 2013-2019 Sam Habiel
	; Copyright 2019 Christopher Edwards
	; Copyright (c) 2022-2024 YottaDB LLC
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

