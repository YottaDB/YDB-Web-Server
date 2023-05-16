%ydbwebjsonDecode ;SLC/KCM -- Decode JSON;2019-11-14  9:06 AM
	;
decode(%ydbjson,%ydbroot,%ydberr)
direct ; TAG for use by decode^%ydbwebjson
	;
	; Examples: do decode^%ydbwebjson("MYJSON","LOCALVAR","LOCALERR")
	;           do decode^%ydbwebjson("^MYJSON(1)","^GLO(99)","^TMP($J)")
	;
	; %ydbjson: string/array containing serialized JSON object
	; %ydbroot: closed array reference for M representation of object
	;  %ydberr: contains error messages, defaults to ^TMP("%ydbwebjsonerr",$J)
	;
	;   %ydbidx: points to next character in JSON string to process
	; %ydbstack: manages stack of subscripts
	;  %ydbprop: true if next string is property name, otherwise treat as value
	;
	; V4W/DLW - Changed %ydbmax from 4000 to 100, same as in the encoder
	; With the change to %ydbmax, the following Unit Tests required changes:
	; splita^%ydbwebjsonDecodeTest, splitb^%ydbwebjsonDecodeTest, long^%ydbwebjsonDecodeTest, maxnum^%ydbwebjsonDecodeTest
	new %ydbmax set %ydbmax=100 ; limit document lines to 100 characters
	set %ydberr=$get(%ydberr,"%ydbwebjsonerr")
	; If a simple string is passed in, move it to an temp array (%ydbinput)
	; so that the processing is consistently on an array.
	if $data(@%ydbjson)=1 new %ydbinput set %ydbinput(1)=@%ydbjson,%ydbjson="%ydbinput"
	set %ydbroot=$name(@%ydbroot@("Z")),%ydbroot=$extract(%ydbroot,1,$length(%ydbroot)-4) ; make open array ref
	new %ydbline,%ydbidx,%ydbstack,%ydbprop,%ydbtype,%ydberrors
	set %ydbline=$order(@%ydbjson@("")),%ydbidx=1,%ydbstack=0,%ydbprop=0,%ydberrors=0
	for  set %ydbtype=$$nxtkn() quit:%ydbtype=""  do  if %ydberrors quit
	. if %ydbtype="{" set %ydbstack=%ydbstack+1,%ydbstack(%ydbstack)="",%ydbprop=1 do:%ydbstack>64 errx("STL{") quit
	. if %ydbtype="}" do  quit
	. . if %ydbstack'>0 do errx("SUF}") quit  ; Extra Brace. Nothing to pop.
	. . if %ydbstack(%ydbstack)?1n.n,%ydbstack(%ydbstack) do errx("OBM") quit  ; Numeric and true only
	. . set %ydbstack=%ydbstack-1
	. if %ydbtype="[" set %ydbstack=%ydbstack+1,%ydbstack(%ydbstack)=1 do:%ydbstack>64 errx("STL[") quit
	. if %ydbtype="]" do:'%ydbstack(%ydbstack) errx("ARM") set %ydbstack=%ydbstack-1 do:%ydbstack<0 errx("SUF]") quit
	. ;
	. ; At this point, we should be in a brace or a bracket (indicated by %ydbstack>0)
	. ; If not we have an error condition
	. if %ydbstack'>0 do errx("TRL",%ydbtype) quit
	. ;
	. if %ydbtype="," do  quit
	. . if +%ydbstack(%ydbstack)=%ydbstack(%ydbstack),%ydbstack(%ydbstack) set %ydbstack(%ydbstack)=%ydbstack(%ydbstack)+1  ; VEN/SMH - next in array
	. . else  set %ydbprop=1                                   ; or next property name
	. if %ydbtype=":" set %ydbprop=0 do:'$length($get(%ydbstack(%ydbstack))) errx("MPN") quit
	. if %ydbtype="""" do  quit
	. . if %ydbprop set %ydbstack(%ydbstack)=$$ues($$nampars(),1) if 1
	. . else  do addstr
	. set %ydbtype=$translate(%ydbtype,"TFN","tfn")
	. if %ydbtype="t" do setbool("t") quit
	. if %ydbtype="f" do setbool("f") quit
	. if %ydbtype="n" do setbool("n") quit
	. if "0123456789+-.eE"[%ydbtype do setnum(%ydbtype) quit  ;S @$$curnode()=$$numpars(%ydbtype) quit
	. do errx("TKN",%ydbtype)
	if %ydbstack'=0 do errx("SCT",%ydbstack)
	quit
nxtkn() ; Move the pointers to the beginning of the next token
	new %ydbdone,%ydbeof,%ydbtoken
	set %ydbdone=0,%ydbeof=0 for  do  quit:%ydbdone!%ydbeof  ; eat spaces & new lines until next visible char
	. if %ydbidx>$length(@%ydbjson@(%ydbline)) set %ydbline=$order(@%ydbjson@(%ydbline)),%ydbidx=1 if '%ydbline set %ydbeof=1 quit
	. if $ascii(@%ydbjson@(%ydbline),%ydbidx)>32 set %ydbdone=1 quit
	. set %ydbidx=%ydbidx+1
	quit:%ydbeof ""  ; we're at the end of input
	set %ydbtoken=$extract(@%ydbjson@(%ydbline),%ydbidx),%ydbidx=%ydbidx+1
	quit %ydbtoken
	;
addstr ; Add string value to current node, escaping text along the way
	; Expects %ydbline,%ydbidx to reference that starting point of the index
	; TODO: add a mechanism to specify names that should not be escaped
	;       just store as ":")= and ":",n)=
	;
	; Happy path -- we find the end quote in the same line
	new %ydbend,%ydbx
	set %ydbend=$find(@%ydbjson@(%ydbline),"""",%ydbidx)
	if %ydbend,($extract(@%ydbjson@(%ydbline),%ydbend-2)'="\") do setstr  quit  ;normal
	if %ydbend,$$iscloseq(%ydbline) do setstr quit  ;close quote preceded by escaped \
	;
	; Less happy path -- first quote wasn't close quote
	new %ydbdone,%ydbtline
	set %ydbdone=0,%ydbtline=%ydbline ; %ydbtline for temporary increment of %ydbline
	for  do  quit:%ydbdone  quit:%ydberrors
	. ;if no quote on current line advance line, scan again
	. if '%ydbend set %ydbtline=%ydbtline+1,%ydbend=1 if '$data(@%ydbjson@(%ydbtline)) do errx("EIQ") quit
	. set %ydbend=$find(@%ydbjson@(%ydbtline),"""",%ydbend)
	. quit:'%ydbend  ; continue on to next line if no quote found on this one
	. if (%ydbend>2),($extract(@%ydbjson@(%ydbtline),%ydbend-2)'="\") set %ydbdone=1 quit  ; found quote position
	. set %ydbdone=$$iscloseq(%ydbtline) ; see if this is an escaped quote or closing quote
	quit:%ydberrors
	; unescape from %ydbidx to %ydbend, using \-extension nodes as necessary
	do uesext
	; now we need to move %ydbline and %ydbidx to next parsing point
	set %ydbline=%ydbtline,%ydbidx=%ydbend
	quit
setstr ; Set simple string value from within same line
	; expects %ydbjson, %ydbline, VVINX, %ydbend
	new %ydbx
	set %ydbx=$extract(@%ydbjson@(%ydbline),%ydbidx,%ydbend-2),%ydbidx=%ydbend
	set @$$curnode()=$$ues(%ydbx)
	; "\s" node indicates value is really a string in case value
	;      collates as numeric or equals boolean keywords
	if %ydbx']]$char(1) set @$$curnode()@("\s")=""
	if %ydbx="true"!(%ydbx="false")!(%ydbx="null") set @$$curnode()@("\s")=""
	if %ydbidx>$length(@%ydbjson@(%ydbline)) set %ydbline=%ydbline+1,%ydbidx=1
	quit
uesext ; unescape from %ydbline,%ydbidx to %ydbtline,%ydbend & extend (\) if necessary
	; expects %ydbline,%ydbidx,%ydbtline,%ydbend
	new %ydbi,%ydby,%ydbstart,%ydbstop,%ydbdone,%ydbbuf,%ydbnode,%ydbmore,%ydbto
	set %ydbnode=$$curnode(),%ydbbuf="",%ydbmore=0,%ydbstop=%ydbend-2
	set %ydbi=%ydbidx,%ydby=%ydbline,%ydbdone=0
	for  do  quit:%ydbdone  quit:%ydberrors
	. set %ydbstart=%ydbi,%ydbi=$find(@%ydbjson@(%ydby),"\",%ydbi)
	. ; if we are on the last line, don't extract past %ydbstop
	. if (%ydby=%ydbtline) set %ydbto=$select('%ydbi:%ydbstop,%ydbi>%ydbstop:%ydbstop,1:%ydbi-2) if 1
	. else  set %ydbto=$select('%ydbi:99999,1:%ydbi-2)
	. do addbuf($extract(@%ydbjson@(%ydby),%ydbstart,%ydbto))
	. if (%ydby'<%ydbtline),(('%ydbi)!(%ydbi>%ydbstop)) set %ydbdone=1 quit  ; now past close quote
	. if '%ydbi set %ydby=%ydby+1,%ydbi=1 quit  ; nothing escaped, go to next line
	. if %ydbi>$length(@%ydbjson@(%ydby)) set %ydby=%ydby+1,%ydbi=1 if '$data(@%ydbjson@(%ydby)) do errx("EIU")
	. new %ydbtgt set %ydbtgt=$extract(@%ydbjson@(%ydby),%ydbi)
	. if %ydbtgt="u" do  if 1
	. . new %ydbtgtc set %ydbtgtc=$extract(@%ydbjson@(%ydby),%ydbi+1,%ydbi+4),%ydbi=%ydbi+4
	. . if $length(%ydbtgtc)<4 set %ydby=%ydby+1,%ydbi=4-$length(%ydbtgtc),%ydbtgtc=%ydbtgtc_$extract(@%ydbjson@(%ydby),1,%ydbi)
	. . do addbuf($char($$dec^%ydbwebutils(%ydbtgtc,16)))
	. else  do addbuf($$realchar(%ydbtgt))
	. set %ydbi=%ydbi+1
	. if (%ydby'<%ydbtline),(%ydbi>%ydbstop) set %ydbdone=1 ; %ydbi incremented past stop
	quit:%ydberrors
	do savebuf
	quit
addbuf(%ydbx) ; add buffer of characters to destination
	; expects %ydbbuf,%ydbmax,%ydbnode,%ydbmore to be defined
	; used directly by addstr
	if $length(%ydbx)+$length(%ydbbuf)>%ydbmax do savebuf
	set %ydbbuf=%ydbbuf_%ydbx
	quit
savebuf ; write out buffer to destination
	; expects %ydbbuf,%ydbmax,%ydbnode,%ydbmore to be defined
	; used directly by addstr,addbuf
	if %ydbmore set @%ydbnode@("\",%ydbmore)=%ydbbuf
	if '%ydbmore set @%ydbnode=%ydbbuf if $length(%ydbbuf)<19,+$extract(%ydbbuf,1,18) set @%ydbnode@("\s")=""
	set %ydbmore=%ydbmore+1,%ydbbuf=""
	quit
iscloseq(%ydbbline) ; return true if this is a closing, rather than escaped, quote
	; expects
	;   %ydbjson: lines of the JSON encoded string
	;    %ydbidx: points to 1st character of the segment
	;   %ydbline: points to the line in which the segment starts
	;    %ydbend: points to 1st character after the " (may be past the end of the line)
	; used directly by addstr
	new %ydbbs,%ydbbidx,%ydbbdone
	set %ydbbs=0,%ydbbidx=%ydbend-2,%ydbbdone=0 ; %ydbbidx starts at 1st character before quote
	; count the backslashes preceding the quote (odd number means the quote was escaped)
	for  do  quit:%ydbbdone!%ydberrors
	. if %ydbbidx<1 do  quit  ; when %ydbbidx<1 go back a line
	. . set %ydbbline=%ydbbline-1 if %ydbbline<%ydbline do errx("RSB") quit
	. . set %ydbbidx=$length(@%ydbjson@(%ydbbline))
	. if $extract(@%ydbjson@(%ydbbline),%ydbbidx)'="\" set %ydbbdone=1 quit
	. set %ydbbs=%ydbbs+1,%ydbbidx=%ydbbidx-1
	quit %ydbbs#2=0  ; %ydbbs is even if this is a close quote
	;
nampars() ; Return parsed name, advancing index past the close quote
	new %ydbend,%ydbdone,%ydbname,%ydbstart
	set %ydbdone=0,%ydbname="",%ydbstart=%ydbidx
	for  do  quit:%ydbdone  quit:%ydberrors
	. set %ydbend=$find(@%ydbjson@(%ydbline),"""",%ydbidx)
	. if $extract(@%ydbjson@(%ydbline),%ydbend-2)="\" set %ydbidx=%ydbend quit
	. if %ydbend set %ydbname=%ydbname_$extract(@%ydbjson@(%ydbline),%ydbstart,%ydbend-2),%ydbidx=%ydbend,%ydbdone=1
	. if '%ydbend set %ydbname=%ydbname_$extract(@%ydbjson@(%ydbline),%ydbstart,$length(@%ydbjson@(%ydbline)))
	. if '%ydbend!(%ydbend>$length(@%ydbjson@(%ydbline))) set %ydbline=%ydbline+1,(%ydbidx,%ydbstart)=1 if '$data(@%ydbjson@(%ydbline)) do errx("ORN")
	; prepend quote if label collates as numeric -- assumes no quotes in label
	if %ydbname']]$char(1) set %ydbname=""""""_%ydbname
	quit %ydbname
	;
setnum(%ydbdigit) ; Set numeric along with any necessary modifier
	new %ydbx
	set %ydbx=$$numpars(%ydbdigit)
	set @$$curnode()=$select(%ydbx["e":+$translate(%ydbx,"e","E"),1:+%ydbx)
	; if numeric is exponent, "0.nnn" or "-0.nnn" store original string
	if +%ydbx'=%ydbx set @$$curnode()@("\n")=%ydbx
	quit
numpars(%ydbdigit) ; Return parsed number, advancing index past end of number
	; %ydbidx intially references the second digit
	new %ydbdone,%ydbnum
	set %ydbdone=0,%ydbnum=%ydbdigit
	for  do  quit:%ydbdone  quit:%ydberrors
	. if '("0123456789+-.eE"[$extract(@%ydbjson@(%ydbline),%ydbidx)) set %ydbdone=1 quit
	. set %ydbnum=%ydbnum_$extract(@%ydbjson@(%ydbline),%ydbidx)
	. set %ydbidx=%ydbidx+1 if %ydbidx>$length(@%ydbjson@(%ydbline)) set %ydbline=%ydbline+1,%ydbidx=1 if '$data(@%ydbjson@(%ydbline)) do errx("OR#")
	quit %ydbnum
	;
setbool(%ydbltr) ; Parse and set boolean value, advancing index past end of value
	new %ydbdone,%ydbbool,%ydbx
	set %ydbdone=0,%ydbbool=%ydbltr
	for  do  quit:%ydbdone  quit:%ydberrors
	. set %ydbx=$translate($extract(@%ydbjson@(%ydbline),%ydbidx),"TRUEFALSN","truefalsn")
	. if '("truefalsn"[%ydbx) set %ydbdone=1 quit
	. set %ydbbool=%ydbbool_%ydbx
	. set %ydbidx=%ydbidx+1 if %ydbidx>$length(@%ydbjson@(%ydbline)) set %ydbline=%ydbline+1,%ydbidx=1 if '$data(@%ydbjson@(%ydbline)) do errx("ORB")
	if %ydbltr="t",(%ydbbool'="true") do errx("EXT",%ydbtype)
	if %ydbltr="f",(%ydbbool'="false") do errx("EXF",%ydbtype)
	if %ydbltr="n",(%ydbbool'="null") do errx("EXN",%ydbtype)
	set @$$curnode()=%ydbbool
	quit
	;
curnode() ; Return a global/local variable name based on %ydbstack
	; Expects %ydbstack to be defined already
	new %ydbi,%ydbsubs
	set %ydbsubs=""
	for %ydbi=1:1:%ydbstack set:%ydbi>1 %ydbsubs=%ydbsubs_"," D
	. ; check numeric with pattern match instead of =+var due to GT.M interperting
	. ; scientific notation as a number instead of a string
	. if %ydbstack(%ydbi)?1N.N set %ydbsubs=%ydbsubs_%ydbstack(%ydbi) ; VEN/SMH Fix psudo array bug.
	. else  set %ydbsubs=%ydbsubs_""""_%ydbstack(%ydbi)_""""
	quit %ydbroot_%ydbsubs_")"
	;
ues(x,key) ; Unescape JSON string
	; copy segments from start to pos-2 (right before \)
	; translate target character (which is at $F position)
	new pos,y,start
	set pos=0,y=""
	for  set start=pos+1 do  quit:start>$length(x)
	. set pos=$find(x,"\",start) ; find next position
	. if 'pos set y=y_$extract(x,start,$length(x)),pos=$length(x) quit
	. ; otherwise handle escaped char
	. new tgt
	. set tgt=$extract(x,pos),y=y_$extract(x,start,pos-2)
	. if tgt="u" set y=y_$char($$dec^%ydbwebutils($extract(x,pos+1,pos+4),16)),pos=pos+4 quit
	. set y=y_$$realchar(tgt,$get(key))
	quit y
	;
realchar(c,key) ; Return actual character from escaped
	if c=""""&'$get(key) quit """" ; Used in the value part and doesn't need double quotes
	if c=""""&$get(key) quit """""" ; Used as part of a set statement and needs double quotes
	if c="/" quit "/"
	if c="\" quit "\"
	if c="b" quit $char(8)
	if c="f" quit $char(12)
	if c="n" quit $char(10)
	if c="r" quit $char(13)
	if c="t" quit $char(9)
	if c="u" ;case covered above in $$DEC^%ydbwebutils calls
	;otherwise
	if $length($get(%ydberr)) do errx("ESC",c)
	quit c
	;
errx(id,val) ; Set the appropriate error message
	do errx^%ydbwebjson(id,$get(val))
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

