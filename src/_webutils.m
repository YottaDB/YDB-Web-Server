%webutils ;SLC/KCM -- Utilities for HTTP communications ;Jun 20, 2022@12:21
 ;
UP(X) Q $TR(X,"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
LOW(X) Q $TR(X,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")
 ;
LTRIM(%X) ; Trim whitespace from left side of string
 ; derived from XLFSTR, but also removes tabs
 N %L,%R
 S %L=1,%R=$L(%X)
 F %L=1:1:$L(%X) Q:$A($E(%X,%L))>32
 Q $E(%X,%L,%R)
 ;
URLENC(X) ; Encode a string for use in a URL
 ; This algorithm is based on https://github.com/lparenteau/DataBallet/blob/master/r/url.m
 ; The old algorithm didn't work for non-UTF8 characters and was designed around ASCII only
 ; Output variable
 N ENCODED S ENCODED=""
 ;
 ; Construct the do not encode array in SAFE (includes English alphabet)
 N I,SAFE
 F I=45,46,95,126,48:1:57,65:1:90,97:1:122 S SAFE(I)=""
 ;
 F I=1:1:$ZL(X) D
 . N BYTE S BYTE=$ZE(X,I) ; Each byte (char)
 . N VAL  S VAL=$ZA(X,I)  ; byte value (0-255)
 . I $D(SAFE(VAL)) S ENCODED=ENCODED_BYTE QUIT
 . I BYTE=" " S ENCODED=ENCODED_"+" QUIT
 . S CODE=$$DEC2HEX(VAL),CODE=$TR($J(CODE,2)," ","0")
 . S ENCODED=ENCODED_"%"_CODE QUIT
 Q ENCODED
 ;
URLDEC(X,PATH) ; Decode a URL-encoded string
 N I,OUT,FRAG,ASC
 S:'$G(PATH) X=$TR(X,"+"," ") ; don't convert '+' in path fragment
 F I=1:1:$L(X,"%") D
 . I I=1 S OUT=$P(X,"%") Q
 . S FRAG=$P(X,"%",I),ASC=$E(FRAG,1,2),FRAG=$E(FRAG,3,$L(FRAG))
 . I $L(ASC) S OUT=OUT_$ZC($$HEX2DEC(ASC))
 . S OUT=OUT_FRAG
 Q OUT
 ;
REFSIZE(ROOT) ; return the size of glvn passed in ROOT
 Q:'$D(ROOT) 0 Q:'$L(ROOT) 0
 Q:$G(ROOT)="" 0
 N SIZE,I
 S SIZE=0
 S ROOT=$NA(@ROOT)
 I $D(@ROOT)#2 S SIZE=$ZL(@ROOT)
 N ORIG,OL S ORIG=ROOT,OL=$QL(ROOT) ; Orig, Orig Length
 F  S ROOT=$Q(@ROOT) Q:ROOT=""  Q:($NA(@ROOT,OL)'=$NA(@ORIG,OL))  S SIZE=SIZE+$ZL(@ROOT)
 S ROOT=ORIG
 Q SIZE
 ;
VARSIZE(V) ; return the size of a variable
 Q:'$D(V) 0
 N SIZE,I
 S SIZE=0
 I $D(V)#2 S SIZE=$ZL(V)
 I $D(V)>1 S I="" F  S I=$O(V(I)) Q:'I  S SIZE=SIZE+$ZL(V(I))
 Q SIZE
 ;
setError(ERRCODE,MESSAGE,ERRARRAY) G setError1
SETERROR(ERRCODE,MESSAGE,ERRARRAY) ; set error info into HTTPERR
setError1 ;
 ; causes HTTPERR system variable to be set
 ; ERRCODE:  query errors are 100-199, update errors are 200-299, M errors are 500
 ; MESSAGE:  additional explanatory material
 ; ERRARRAY: An Array to use instead of the Message for information to the user.
 ;
 N ERRNAME,TOPMSG
 S HTTPERR=400,TOPMSG="Bad Request"
 ; update errors (200-299)
 I ERRCODE=201 S ERRNAME="Unable to encode JSON"
 I ERRCODE=202 S ERRNAME="Unable to decode JSON"
 ; Generic Errors
 I ERRCODE=301 S ERRNAME="Required variable undefined"
 ; HTTP errors
 I ERRCODE=400 S ERRNAME="Bad Request"
 I ERRCODE=401 S ERRNAME="Unauthorized" ; VEN/SMH
 I ERRCODE=404 S ERRNAME="Not Found"
 I ERRCODE=405 S ERRNAME="Method Not Allowed"
 ; system errors (500-599)
 I ERRCODE=501 S ERRNAME="M execution error"
 I ERRCODE=502 S ERRNAME="Unable to lock record"
 I '$L($G(ERRNAME)) S ERRNAME="Unknown error"
 ;
 I ERRCODE>500 S HTTPERR=500,TOPMSG="Internal Server Error"  ; M Server Error
 I ERRCODE<500,ERRCODE>400 S HTTPERR=ERRCODE,TOPMSG=ERRNAME  ; Other HTTP Errors
 ;
 I $I(HTTPERR("count"))
 S HTTPERR("apiVersion")="1.0"
 S HTTPERR("error","code")=HTTPERR
 S HTTPERR("error","message")=TOPMSG
 S HTTPERR("error","request")=$G(HTTPREQ("method"))_" "_$G(HTTPREQ("path"))_" "_$G(HTTPREQ("query"))
 I $D(ERRARRAY) D
 . M HTTPERR("error","errors",HTTPERR("count"))=ERRARRAY  ; VEN/SMH
 E  D
 . S HTTPERR("error","errors",HTTPERR("count"),"reason")=ERRCODE
 . S HTTPERR("error","errors",HTTPERR("count"),"message")=ERRNAME
 I $L($G(MESSAGE)) S HTTPERR("error","errors",HTTPERR("count"),"domain")=MESSAGE
 Q
customError(ERRCODE,ERRARRAY) ; set custom error into HTTPERR
 S HTTPERR=ERRCODE
 M HTTPERR=ERRARRAY
 QUIT
 ;
 ; Cache specific functions (selected one support GT.M too!)
 ;
GMT() ; return HTTP date string (this is really using UTC instead of GMT)
 N TM,DAY
 N OUT
 N D S D="datetimepipe"
 N OLDIO S OLDIO=$I
 O D:(shell="/bin/sh":comm="date -u +'%a, %d %b %Y %H:%M:%S %Z'|sed 's/UTC/GMT/g'")::"pipe"
 U D R OUT:1 
 U OLDIO C D
 Q OUT
 ;
DEC2HEX(NUM) ; return a decimal number as hex
 Q $$BASE(NUM,10,16)
 ;
HEX2DEC(HEX) ; return a hex number as decimal
 Q $$BASE(HEX,16,10)
 ;
BASE(%X1,%X2,%X3) ;Convert %X1 from %X2 base to %X3 base
 I (%X2<2)!(%X2>16)!(%X3<2)!(%X3>16) Q -1
 Q $$CNV($$DEC(%X1,%X2),%X3)
DEC(N,B) ;Cnv N from B to 10
 Q:B=10 N N I,Y S Y=0
 F I=1:1:$L(N) S Y=Y*B+($F("0123456789ABCDEF",$E(N,I))-2)
 Q Y
CNV(N,B) ;Cnv N from 10 to B
 Q:B=10 N N I,Y S Y=""
 F I=1:1 S Y=$E("0123456789ABCDEF",N#B+1)_Y,N=N\B Q:N<1
 Q Y
 ;
HTFM(%H,%F) ;$H to FM, %F=1 for date only
 N X,%,%T,%Y,%M,%D S:'$D(%F) %F=0
 I $$HR(%H) Q -1 ;Check Range
 I '%F,%H[",0" S %H=(%H-1)_",86400"
 D YMD S:%T&('%F) X=X_%T
 Q X
YMD ;21608 = 28 feb 1900, 94657 = 28 feb 2100, 141 $H base year
 S %=(%H>21608)+(%H>94657)+%H-.1,%Y=%\365.25+141,%=%#365.25\1
 S %D=%+306#(%Y#4=0+365)#153#61#31+1,%M=%-%D\29+1
 S X=%Y_"00"+%M_"00"+%D,%=$P(%H,",",2)
 S %T=%#60/100+(%#3600\60)/100+(%\3600)/100 S:'%T %T=".0"
 Q
HR(%V) ;Check $H in valid range
 Q (%V<2)!(%V>99999)
 ;
HTE(%H,%F) ;$H to external
 Q:$$HR(%H) %H ;Range Check
 N Y,%T,%R
 S %F=$G(%F,1) S Y=$$HTFM(%H,0)
T2 S %T="."_$E($P(Y,".",2)_"000000",1,7)
 D FMT Q %R
FMT ;
 N %G S %G=+%F
 G F1:%G=1,F2:%G=2,F3:%G=3,F4:%G=4,F5:%G=5,F6:%G=6,F7:%G=7,F8:%G=8,F9:%G=9,F1
 Q
 ;
F1 ;Apr 10, 2002
 S %R=$P($$M()," ",$S($E(Y,4,5):$E(Y,4,5)+2,1:0))_$S($E(Y,4,5):" ",1:"")_$S($E(Y,6,7):$E(Y,6,7)_", ",1:"")_($E(Y,1,3)+1700)
 ;
TM ;All formats come here to format Time.
 N %,%S Q:%T'>0!(%F["D")
 I %F'["P" S %R=%R_"@"_$E(%T,2,3)_":"_$E(%T,4,5)_$S(%F["M":"",$E(%T,6,7)!(%F["S"):":"_$E(%T,6,7),1:"")
 I %F["P" D
 . S %R=%R_" "_$S($E(%T,2,3)>12:$E(%T,2,3)-12,+$E(%T,2,3)=0:"12",1:+$E(%T,2,3))_":"_$E(%T,4,5)_$S(%F["M":"",$E(%T,6,7)!(%F["S"):":"_$E(%T,6,7),1:"")
 . S %R=%R_$S($E(%T,2,7)<120000:" am",$E(%T,2,3)=24:" am",1:" pm")
 . Q
 Q
 ;Return Month names
M() Q "  Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
 ;
F2 ;4/10/02
 S %R=$J(+$E(Y,4,5),2)_"/"_$J(+$E(Y,6,7),2)_"/"_$E(Y,2,3)
 S:%F["Z" %R=$TR(%R," ","0") S:%F'["F" %R=$TR(%R," ")
 G TM
F3 ;10/4/02
 S %R=$J(+$E(Y,6,7),2)_"/"_$J(+$E(Y,4,5),2)_"/"_$E(Y,2,3)
 S:%F["Z" %R=$TR(%R," ","0") S:%F'["F" %R=$TR(%R," ")
 G TM
F4 ;02/4/10
 S %R=$E(Y,2,3)_"/"_$J(+$E(Y,4,5),2)_"/"_$J(+$E(Y,6,7),2)
 S:%F["Z" %R=$TR(%R," ","0") S:%F'["F" %R=$TR(%R," ")
 G TM
F5 ;4/10/2002
 S %R=$J(+$E(Y,4,5),2)_"/"_$J(+$E(Y,6,7),2)_"/"_($E(Y,1,3)+1700)
 S:%F["Z" %R=$TR(%R," ","0") S:%F'["F" %R=$TR(%R," ")
 G TM
F6 ;10/4/2002
 S %R=$J(+$E(Y,6,7),2)_"/"_$J(+$E(Y,4,5),2)_"/"_($E(Y,1,3)+1700)
 S:%F["Z" %R=$TR(%R," ","0") S:%F'["F" %R=$TR(%R," ")
 G TM
F7 ;2002/4/10
 S %R=($E(Y,1,3)+1700)_"/"_$J(+$E(Y,4,5),2)_"/"_$J(+$E(Y,6,7),2)
 S:%F["Z" %R=$TR(%R," ","0") S:%F'["F" %R=$TR(%R," ")
 G TM
F8 ;10 Apr 02
 S %R=$S($E(Y,6,7):$E(Y,6,7)_" ",1:"")_$P($$M()," ",$S($E(Y,4,5):$E(Y,4,5)+2,1:0))_$S($E(Y,4,5):" ",1:"")_$E(Y,2,3)
 G TM
F9 ;10 Apr 2002
 S %R=$S($E(Y,6,7):$E(Y,6,7)_" ",1:"")_$P($$M()," ",$S($E(Y,4,5):$E(Y,4,5)+2,1:0))_$S($E(Y,4,5):" ",1:"")_($E(Y,1,3)+1700)
 G TM
 ;
PARSE10(BODY,PARSED) ; Parse BODY by CRLF and return the array in PARSED
 ; Input: BODY: By Ref - BODY to be parsed
 ; Output: PARSED: By Ref - PARSED Output
 ; E.g. if BODY is ABC_CRLF_DEF_CRLF, PARSED is PARSED(1)="ABC",PARSED(2)="DEF",PARSED(3)=""
 N LL S LL="" ; Last line
 N L S L=1 ; Line counter.
 K PARSED ; Kill return array
 N I S I="" F  S I=$O(BODY(I)) Q:'I  D  ; For each 4000 character block
 . N J F J=1:1:$L(BODY(I),$C(10)) D  ; For each line
 . . S:(J=1&(L>1)) L=L-1 ; Replace old line (see 2 lines below)
 . . S PARSED(L)=$TR($P(BODY(I),$C(10),J),$C(13)) ; Get line; Take CR out if there.
 . . S:(J=1&(L>1)) PARSED(L)=LL_PARSED(L) ; If first line, append the last line before it and replace it.
 . . S LL=PARSED(L) ; Set last line
 . . S L=L+1 ; LineNumber++
 QUIT
 ;
ADDCRLF(RESULT) ; Add CRLF to each line
 I $E($G(RESULT))="^" D  QUIT  ; Global
 . N V,QL S V=RESULT,QL=$QL(V) F  S V=$Q(@V) Q:V=""  Q:$NA(@V,QL)'=RESULT  S @V=@V_$C(13,10)
 E  D  ; Local variable passed by reference
 . I $D(RESULT)#2 S RESULT=RESULT_$C(13,10)
 . N V S V=$NA(RESULT) F  S V=$Q(@V) Q:V=""  S @V=@V_$C(13,10)
 QUIT
 ;
UNKARGS(ARGS,LIST) ; returns true if any argument is unknown
 N X,UNKNOWN
 S UNKNOWN=0,LIST=","_LIST_","
 S X="" F  S X=$O(ARGS(X)) Q:X=""  I LIST'[(","_X_",") D
 . S UNKNOWN=1
 . D SETERROR(111,X)
 Q UNKNOWN
 ;
ENCODE64(X) ;
 N RGZ,RGZ1,RGZ2,RGZ3,RGZ4,RGZ5,RGZ6
 S RGZ=$$INIT64,RGZ1=""
 F RGZ2=1:3:$L(X) D
 .S RGZ3=0,RGZ6=""
 .F RGZ4=0:1:2 D
 ..S RGZ5=$A(X,RGZ2+RGZ4),RGZ3=RGZ3*256+$S(RGZ5<0:0,1:RGZ5)
 .F RGZ4=1:1:4 S RGZ6=$E(RGZ,RGZ3#64+2)_RGZ6,RGZ3=RGZ3\64
 .S RGZ1=RGZ1_RGZ6
 S RGZ2=$L(X)#3
 S:RGZ2 RGZ3=$L(RGZ1),$E(RGZ1,RGZ3-2+RGZ2,RGZ3)=$E("==",RGZ2,2)
 Q RGZ1
DECODE64(X) ;
 N RGZ,RGZ1,RGZ2,RGZ3,RGZ4,RGZ5,RGZ6
 S RGZ=$$INIT64,RGZ1=""
 F RGZ2=1:4:$L(X) D
 .S RGZ3=0,RGZ6=""
 .F RGZ4=0:1:3 D
 ..S RGZ5=$F(RGZ,$E(X,RGZ2+RGZ4))-3
 ..S RGZ3=RGZ3*64+$S(RGZ5<0:0,1:RGZ5)
 .F RGZ4=0:1:2 S RGZ6=$C(RGZ3#256)_RGZ6,RGZ3=RGZ3\256
 .S RGZ1=RGZ1_RGZ6
 Q $E(RGZ1,1,$L(RGZ1)-$L(X,"=")+1)
INIT64() Q "=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
 ;
addService(method,urlPattern,routine,auth,authKey,authOption,params) ; [Public: Add Service Entry Point]
 ; pass all by value except params by ref
 ; do or $$; return if $$ is 0 for failure and ien for success
 ; param format:
 ; - param(1)="U^rpc" URL Component named RPC
 ; - param(2)="F^start" Form Body variable called start
 ; - param(3)="Q^dir" HTTP Query variable called dir
 ; - param(4)="B"     Pass the body
 set method=$get(method)
 set urlPattern=$get(urlPattern)
 set routine=$get(routine)
 ;
 ; validate method
 if "^GET^POST^PUT^OPTIONS^DELETE^TRACE^HEAD^CONNECT^"'["^"_method_"^" quit:$q 0 q
 ;
 ; if urlPattern or routine are empty, bad call
 if urlPattern=""!(routine="") quit:$q 0 q
 ;
 ; Remove leading slashes
 if $e(urlPattern)="/" s $e(urlPattern)=""
 ;
 ; Lock for edits
 tstart ():serial
 ;
 ; does it already exist; or add new entry
 new ien
 if $data(^%web(17.6001,"B",method,urlPattern)) do
 . new routine set routine=$order(^%web(17.6001,"B",method,urlPattern,""))
 . set ien=$order(^%web(17.6001,"B",method,urlPattern,routine,0))
 . kill ^%web(17.6001,"B",method,urlPattern)
 . set $piece(^%web(17.6001,0),"^",3)=ien
 else  do 
 . set ien=$o(^%web(17.6001," "),-1)+1
 . set $piece(^%web(17.6001,0),"^",3,4)=ien_"^"_ien
 ;
 ; now add the entry at this ien
 ; kill old one first
 kill ^%web(17.6001,ien)
 ;
 ; Add new one
 set ^%web(17.6001,ien,0)=method
 set ^%web(17.6001,ien,1)=urlPattern
 set ^%web(17.6001,ien,2)=routine
 set ^%web(17.6001,"B",method,urlPattern,routine,ien)=""
 ;
 ; Add Auth nodes
 if $text(^XUS)'="" do
 . if $g(auth)           set $piece(^%web(17.6001,ien,"AUTH"),"^",1)=1
 . if $g(authKey)'=""    set $piece(^%web(17.6001,ien,"AUTH"),"^",2)=$$FIND1^DIC(19.1,,"QX",authKey,"B")
 . if $g(authOption)'="" set $piece(^%web(17.6001,ien,"AUTH"),"^",3)=$$FIND1^DIC(19,,"QX",authOption,"B")
 ;
 ; Add Params
 if $order(params("")) do
 . new n for n=0:0 set n=$order(params(n)) quit:'n  set ^%web(17.6001,ien,"PARAMS",n,0)=params(n)
 . new lastn s lastn=+$order(params(""),-1)
 . set ^%web(17.6001,ien,"PARAMS",0)="^17.60012S^"_lastn_"^"_lastn
 ;
 ; Commit our changes and unlock
 tcommit
 ;
 ; Return IEN
 quit:$quit ien quit
 ;
deleteService(method,urlPattern) ; [Public: Delete Service]
 set method=$get(method)
 set urlPattern=$get(urlPattern)
 if method="" quit
 if urlPattern="" quit
 ;
 ; Remove leading slashes
 if $e(urlPattern)="/" s $e(urlPattern)=""
 ;
 new ien
 tstart ():serial
 if $data(^%web(17.6001,"B",method,urlPattern)) do
 . new routine set routine=$order(^%web(17.6001,"B",method,urlPattern,""))
 . set ien=$order(^%web(17.6001,"B",method,urlPattern,routine,0))
 . kill ^%web(17.6001,"B",method,urlPattern)
 . kill ^%web(17.6001,ien)
 . set $piece(^%web(17.6001,0),"^",3)=ien
 . set $piece(^%web(17.6001,0),"^",4)=$piece(^%web(17.6001,0),"^",4)-1
 tcommit
 ;
 quit
 ;
 ; Portions of this code are public domain, but it was extensively modified
 ; Copyright (c) 2013-2019 Sam Habiel
 ; Copyright (c) 2022 YottaDB LLC
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
