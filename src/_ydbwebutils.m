%ydbwebutils ;SLC/KCM -- Utilities for HTTP communications ;Jun 20, 2022@12:21
	;
urlenc(x) ; Encode a string for use in a URL
	; This algorithm is based on https://github.com/lparenteau/DataBallet/blob/master/r/url.m
	; The old algorithm didn't work for non-UTF8 characters and was designed around ASCII only
	; Output variable
	new encoded set encoded=""
	;
	; Construct the do not encode array in SAFE (includes English alphabet)
	new i,safe
	for i=45,46,95,126,48:1:57,65:1:90,97:1:122 set safe(i)=""
	;
	for i=1:1:$zlength(x) d
	. new byte set byte=$zextract(x,i) ; each byte (char)
	. new val  set val=$zascii(x,i)  ; byte value (0-255)
	. if $data(safe(val)) set encoded=encoded_byte quit
	. if byte=" " set encoded=encoded_"+" quit
	. set code=$$dec2hex(val),code=$translate($justify(code,2)," ","0")
	. set encoded=encoded_"%"_code quit
	quit encoded
	;
urldec(x,path) ; Decode a URL-encoded string
	new i,out,frag,asc
	set:'$get(path) x=$translate(x,"+"," ") ; don't convert '+' in path fragment
	for i=1:1:$length(x,"%") d
	. if i=1 set out=$zpiece(x,"%") q
	. set frag=$zpiece(x,"%",i),asc=$extract(frag,1,2),frag=$extract(frag,3,$length(frag))
	. if $length(asc) set out=out_$zchar($$hex2dec(asc))
	. set out=out_frag
	quit out
	;
refsize(root) ; return the size of glvn passed in root
	quit:'$data(root) 0 quit:'$length(root) 0
	quit:$get(root)="" 0
	new size,i
	set size=0
	set root=$na(@root)
	if $data(@root)#2 set size=$zlength(@root)
	new orig,ol set orig=root,ol=$qlength(root) ; orig, orig length
	for  set root=$query(@root) quit:root=""  quit:($na(@root,ol)'=$na(@orig,ol))  set size=size+$zlength(@root)
	set root=orig
	quit size
	;
varsize(v) ; return the size of a variable
	quit:'$data(v) 0
	new size,i
	set size=0
	if $data(v)#2 set size=$zlength(v)
	if $data(v)>1 set i="" for  set i=$o(v(i)) quit:'i  set size=size+$zlength(v(i))
	quit size
	;
setError(errcode,message,errarray)
	; causes httperr system variable to be set
	; errcode:  query errors are 100-199, update errors are 200-299, M errors are 500
	; message:  additional explanatory material
	; errarray: An Array to use instead of the Message for information to the user.
	;
	new errname,topmsg
	set httperr=400,topmsg="Bad Request"
	; update errors (200-299)
	if errcode=201 set errname="Unable to encode JSON"
	if errcode=202 set errname="Unable to decode JSON"
	; Generic Errors
	if errcode=301 set errname="Required variable undefined"
	; HTTP errors
	if errcode=400 set errname="Bad Request"
	if errcode=401 set errname="Unauthorized"
	if errcode=403 set errname="Forbidden"
	if errcode=404 set errname="Not Found"
	if errcode=405 set errname="Method Not Allowed"
	if errcode=408 set errname="Token Timeout"
	; system errors (500-599)
	if errcode=501 set errname="M execution error"
	if errcode=502 set errname="Unable to lock record"
	if '$length($get(errname)) set errname="Unknown error"
	;
	if errcode>500 set httperr=500,topmsg="Internal Server Error"  ; M Server Error
	if errcode<500,errcode>400 set httperr=errcode,topmsg=errname  ; Other HTTP Errors
	;
	if $increment(httperr("count"))
	set httperr("apiVersion")="1.1"
	set httperr("error","code")=httperr
	set httperr("error","toperror")=topmsg
	set httperr("error","request")=$get(HTTPREQ("method"))_" "_$get(HTTPREQ("path"))_" "_$get(HTTPREQ("query"))
	if $data(errarray) do
	. set httperr("error","errors",httperr("count"),"reason")=message
	. merge httperr("error","errors",httperr("count"),"message")=errarray
	else  do
	. set httperr("error","errors",httperr("count"),"reason")=errcode
	. set httperr("error","errors",httperr("count"),"errname")=errname
	. set httperr("error","errors",httperr("count"),"message")=message
	quit
customError(errcode,errarray) ; set custom error into httperr
	set httperr=errcode
	merge httperr=errarray
	quit
	;
	;
GMT() ; return HTTP date string (this is really using UTC instead of GMT)
	new tm,day
	new out
	new d set d="datetimepipe"
	new oldio set oldio=$i
	open d:(shell="/bin/sh":comm="date -u +'%a, %d %b %Y %H:%M:%S %Z'|sed 's/UTC/GMT/g'")::"pipe"
	use d read out:1 
	use oldio close d
	quit out
	;
dec2hex(num) ; return a decimal number as hex
	quit $$base(num,10,16)
	;
hex2dec(hex) ; return a hex number as decimal
	quit $$base(hex,16,10)
	;
base(%x1,%x2,%x3) ;convert %x1 from %x2 base to %x3 base
	if (%x2<2)!(%x2>16)!(%x3<2)!(%x3>16) quit -1
	quit $$cnv($$dec(%x1,%x2),%x3)
dec(n,b) ;cnv n from b to 10
	quit:b=10 n
	n i,y set y=0
	for i=1:1:$length(n) set y=y*b+($find("0123456789ABCDEF",$extract(n,i))-2)
	quit y
cnv(n,b) ;Cnv n from 10 to b
	quit:b=10 n
	new i,y set y=""
	for i=1:1 set y=$extract("0123456789ABCDEF",n#b+1)_y,n=n\b quit:n<1
	quit y
	;
parse10(body,parsed) ; Parse BODY by CRLF and return the array in PARSED
	; Input: body: By Ref - body to be parsed
	; Output: parsed: By Ref - parsed Output
	; E.g. if body is ABC_CRLF_DEF_CRLF, parsed is parsed(1)="ABC",parsed(2)="DEF",parsed(3)=""
	new ll set ll="" ; Last line
	new l set l=1 ; Line counter.
	kill parsed ; Kill return array
	new i set i="" for  set i=$o(body(i)) quit:'i  do  ; for each 4000 character block
	. new j for j=1:1:$length(body(i),$char(10)) do  ; for each line
	. . set:(j=1&(l>1)) l=l-1 ; replace old line (see 2 lines below)
	. . set parsed(l)=$translate($zpiece(body(i),$char(10),j),$char(13)) ; get line; take cr out if there.
	. . set:(j=1&(l>1)) parsed(l)=ll_parsed(l) ; if first line, append the last line before it and replace it.
	. . set ll=parsed(l) ; set last line
	. . set l=l+1 ; linenumber++
	QUIT
	;
addcrlf(result) ; add crlf to each line
	if $extract($get(result))="^" do  quit  ; global
	. new v,ql set v=result,ql=$qlength(v) for  set v=$query(@v) quit:v=""  quit:$na(@v,ql)'=result  set @v=@v_$char(13,10)
	else  do  ; local variable passed by reference
	. if $data(result)#2 set result=result_$char(13,10)
	. n v s v=$na(result) for  set v=$query(@v) quit:v=""  set @v=@v_$char(13,10)
	quit
	;
unkargs(args,list) ; returns true if any argument is unknown
	new x,unknown
	set unknown=0,list=","_list_","
	set x="" for  set x=$o(args(x)) quit:x=""  if list'[(","_x_",") do
	. set unknown=1
	. do setError(111,x)
	quit unknown
	;
encode64(x) ;
	new z,z1,z2,z3,z4,z5,z6
	set z=$$init64,z1=""
	for z2=1:3:$length(x) d
	.s z3=0,z6=""
	.f z4=0:1:2 d
	..s z5=$ascii(x,z2+z4),z3=z3*256+$select(z5<0:0,1:z5)
	.f z4=1:1:4 set z6=$extract(z,z3#64+2)_z6,z3=z3\64
	.s z1=z1_z6
	set z2=$length(x)#3
	set:z2 z3=$length(z1),$extract(z1,z3-2+z2,z3)=$extract("==",z2,2)
	quit z1
decode64(x) ;
	new z,z1,z2,z3,z4,z5,z6
	set z=$$init64,z1=""
	for z2=1:4:$length(x) d
	.s z3=0,z6=""
	.f z4=0:1:3 d
	..s z5=$find(z,$extract(x,z2+z4))-3
	..s z3=z3*64+$select(z5<0:0,1:z5)
	.f z4=0:1:2 set z6=$char(z3#256)_z6,z3=z3\256
	.s z1=z1_z6
	quit $extract(z1,1,$length(z1)-$length(x,"=")+1)
init64() quit "=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	;
sstep	; --log 4 single stepping code
	set $zstep="new oio x:$io'=parentStdout ""set oio=$IO open parentStdout use parentStdout"" write $justify($zpos,25)_"":""_$text(@$zpos),! x:$d(oio) ""use oio close parentStdout"" zstep into"
	zbreak sstep+3:"zstep into"
	new oldIO set oldIO=$IO
	open parentStdout use parentStdout
	write !,"Stepping STARTED",!
	use oldIO close parentStdout
	quit
	;
stdout(msg) ; [Internal] Log to STDOUT
	; 127.0.0.1 - - [02/Sep/2022 11:03:33] "GET / HTTP/1.1" 200 -
	quit:'parentStdoutAvailable ; Device not writable
	new oldIO set oldIO=$IO
	open parentStdout use parentStdout
	write httpremoteip," - - [",$ZDATE($H,"DD/MON/YYYY 12:60:SS AM"),"] "
	write msg,!
	use oldIO close parentStdout
	quit
	;
stdoutzw(v)
	quit:'parentStdoutAvailable ; Device not writable
	new oldIO set oldIO=$IO
	open parentStdout use parentStdout
	zwrite @v
	use oldIO close parentStdout
	quit
	;
stdoutavail(d) ; $$ Is STDOUT available to write to?
	new $etrap set $etrap="set $ecode="""" quit 0"
	open d close d
	quit 1
	;
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright (c) 2013-2019 Sam Habiel
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

