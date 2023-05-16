%ydbwebjsonEncode ;SLC/KCM -- Encode JSON;2019-11-14  9:06 AM
	;
encode(%ydbroot,%ydbjson,%ydberr)
direct ; TAG for use by encode^%ydbwebjson
	;
	; Examples:  do encode^%ydbwebjson("^GLO(99,2)","^TMP($J)")
	;            do encode^%ydbwebjson("LOCALVAR","MYJSON","LOCALERR")
	;
	; %ydbroot: closed array reference for M representation of object
	; %ydbjson: destination variable for the string array formatted as JSON
	;  %ydberr: contains error messages, defaults to ^TMP("%ydbwebjsonerr",$J)
	;
	set %ydberr=$get(%ydberr,"%ydbwebjsonerr")
	new %ydbline,%ydbmax,%ydbsub,%ydberrors
	;
	; V4W/DLW - Changed %ydbmax from 4000 (just under the 4096 string size limit)
	; to 100. With large data arrays, the JSON encoder could exhaust system
	; memory, which required a switch to globals to fix. However, 4000 as a
	; limit slowed the encoder down quite a bit, when using globals.
	; With the change to %ydbmax, the following Unit Tests required changes:
	; purenum^%ydbwebjsonDecodeTest,
	; estring^%ydbwebjsonDecodeTest, basic^%ydbwebjsonEncodeTest, vals^%ydbwebjsonEncodeTest, long^%ydbwebjsonEncodeTest,
	; pre^%ydbwebjsonEncodeTest, wp^%ydbwebjsonEncodeTest, example^%ydbwebjsonEncodeTest
	set %ydbline=1,%ydbmax=100,%ydberrors=0 ; limit document lines to 100 characters
	set @%ydbjson@(%ydbline)=""
	; If first subscript is numeric, run array code and done
	; https://groups.google.com/d/msg/comp.lang.mumps/RcogxQKtkJw/lN7AzAVzBAAJ
	set %ydbsub=$order(@%ydbroot@(""))
	if +%ydbsub=%ydbsub do
	. do serary(%ydbroot)
	else  do
	. do serobj(%ydbroot)
	quit
	;
serobj(%ydbroot) ; Serialize into a JSON object
	new %ydbfirst,%ydbsub,%ydbnext
	set @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_"{"
	set %ydbfirst=1
	set %ydbsub="" for  set %ydbsub=$order(@%ydbroot@(%ydbsub)) quit:%ydbsub=""  do
	. set:'%ydbfirst @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_"," set %ydbfirst=0
	. ; get the name part
	. do sername(%ydbsub)
	. ; if this is a value, serialize it
	. if $$isvalue(%ydbroot,%ydbsub) do serval(%ydbroot,%ydbsub) quit
	. ; otherwise navigate to the next child object or array
	. if $data(@%ydbroot@(%ydbsub))=10 set %ydbnext=$order(@%ydbroot@(%ydbsub,"")) do  quit
	. . ; Need to check if numeric representation matches string representation to decide if it is an array
	. . if +%ydbnext=%ydbnext do serary($name(@%ydbroot@(%ydbsub))) if 1
	. . else  do serobj($name(@%ydbroot@(%ydbsub)))
	. do errx("SOB",%ydbsub)  ; should quit loop before here
	set @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_"}"
	quit
serary(%ydbroot) ; Serialize into a JSON array
	new %ydbfirst,%ydbi,%ydbnext
	set @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_"["
	set %ydbfirst=1
	set %ydbi=0 for  set %ydbi=$order(@%ydbroot@(%ydbi)) quit:'%ydbi  do
	. set:'%ydbfirst @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_"," set %ydbfirst=0
	. if $$isvalue(%ydbroot,%ydbi) do serval(%ydbroot,%ydbi) quit  ; write value
	. if $data(@%ydbroot@(%ydbi))=10 set %ydbnext=$order(@%ydbroot@(%ydbi,"")) do  quit
	. . ; Need to check if numeric representation matches string representation to decide if it is an array
	. . if +%ydbnext=%ydbnext do serary($name(@%ydbroot@(%ydbi))) if 1
	. . else  do serobj($name(@%ydbroot@(%ydbi)))
	. do errx("SAR",%ydbi)  ; should quit loop before here
	set @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_"]"
	quit
sername(%ydbsub) ; Serialize the object name into JSON string
	if $extract(%ydbsub)="""" set %ydbsub=$extract(%ydbsub,2,$length(%ydbsub)) ; quote indicates numeric label
	if ($length(%ydbsub)+$length(@%ydbjson@(%ydbline)))>%ydbmax set %ydbline=%ydbline+1,@%ydbjson@(%ydbline)=""
	set @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_""""_$$esc(%ydbsub)_""""_":"
	quit
serval(%ydbroot,%ydbsub) ; Serialize X into appropriate JSON representation
	new %ydbx,%ydbi,%ydbdone
	; if the node is already in JSON format, just add it
	if $data(@%ydbroot@(%ydbsub,":")) do  quit  ; <-- jump out here if preformatted
	. set %ydbx=$get(@%ydbroot@(%ydbsub,":")) do:$length(%ydbx) concat
	. set %ydbi=0 for  set %ydbi=$order(@%ydbroot@(%ydbsub,":",%ydbi)) quit:'%ydbi  set %ydbx=@%ydbroot@(%ydbsub,":",%ydbi) do concat
	;
	set %ydbx=$get(@%ydbroot@(%ydbsub)),%ydbdone=0
	; handle the numeric, boolean, and null types
	if $data(@%ydbroot@(%ydbsub,"\n")) set:$length(@%ydbroot@(%ydbsub,"\n")) %ydbx=@%ydbroot@(%ydbsub,"\n") do concat quit  ; when +X'=X
	if '$data(@%ydbroot@(%ydbsub,"\s")),$length(%ydbx) do  quit:%ydbdone
	. if %ydbx']]$char(1) set %ydbx=$$jnum(%ydbx) do concat set %ydbdone=1 quit
	. if %ydbx="true"!(%ydbx="false")!(%ydbx="null") do concat set %ydbdone=1 quit
	; otherwise treat it as a string type
	set %ydbx=""""_$$esc(%ydbx) ; open quote
	do concat
	if $data(@%ydbroot@(%ydbsub,"\")) do  ; handle continuation nodes
	. set %ydbi=0 for  set %ydbi=$order(@%ydbroot@(%ydbsub,"\",%ydbi)) quit:'%ydbi   do
	. . set %ydbx=$$esc(@%ydbroot@(%ydbsub,"\",%ydbi))
	. . do concat
	set %ydbx="""" do concat    ; close quote
	quit
concat ; come here to concatenate to JSON string
	if ($length(%ydbx)+$length(@%ydbjson@(%ydbline)))>%ydbmax set %ydbline=%ydbline+1,@%ydbjson@(%ydbline)=""
	set @%ydbjson@(%ydbline)=@%ydbjson@(%ydbline)_%ydbx
	quit
isvalue(%ydbroot,%ydbsub) ; Return true if this is a value node
	if $data(@%ydbroot@(%ydbsub))#2 quit 1
	new %ydbx set %ydbx=$order(@%ydbroot@(%ydbsub,""))
	quit:%ydbx="\" 1  ; word processing continuation node
	quit:%ydbx=":" 1  ; pre-formatted JSON node
	quit 0
	;
numeric(X) ; Return true if the numeric
	if $length(X)>18 quit 0        ; string (too long for numeric)
	if X=0 quit 1             ; numeric (value is zero)
	if +X=0 quit 0            ; string
	if $extract(X,1)="." quit 0     ; not a JSON number (although numeric in M)
	if $extract(X,1,2)="-." quit 0  ; not a JSON number
	if +X=X quit 1            ; numeric
	if X?1"0."1.n quit 1      ; positive fraction
	if X?1"-0."1.N quit 1     ; negative fraction
	set X=$translate(X,"e","E")
	if X?.1"-"1.N.1".".N1"E".1"+"1.N quit 1  ; {-}99{.99}E{+}99
	if X?.1"-"1.N.1".".N1"E-"1.N quit 1      ; {-}99{.99}E-99
	quit 0
	;
esc(x) ; Escape string for JSON
	new y,i,pair,from,to
	set y=x
	for pair="\\","""""","//",$char(8,98),$char(12,102),$char(10,110),$char(13,114),$char(9,116) do
	. set from=$extract(pair),to=$extract(pair,2)
	. set x=y,y=$zpiece(x,from) for i=2:1:$length(x,from) set y=y_"\"_to_$zpiece(x,from,i)
	if y?.e1.c.e set x=y,y="" for i=1:1:$length(x) set from=$ascii(x,i) do
	. ; skip nul character, otherwise encode ctrl-char
	. if from<32 quit:from=0  set y=y_$$ucode(from) quit
	. if from>126,(from<160) set y=y_$$ucode(from) quit
	. set y=y_$extract(x,i)
	quit y
	;
jnum(n) ; Return JSON representation of a number
	if n'<1 quit n
	if n'>-1 quit n
	if n>0 quit "0"_n
	if n<0 quit "-0"_$zpiece(n,"-",2,9)
	quit n
	;
ucode(c) ; Return \u00nn representation of decimal character value
	new h set h="0000"_$$cnv^%ydbwebutils(c,16)
	quit "\u"_$extract(h,$length(h)-3,$length(h))
	;
errx(id,val) ; Set the appropriate error message
	do errx^%ydbwebjson(id,$get(val))
	quit
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright 2016 Accenture Federal Services
	; Copyright 2013-2019 Sam Habiel
	; Copyright 2019 Christopher Edwards
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

