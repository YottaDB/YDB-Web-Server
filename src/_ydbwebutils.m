%ydbwebutils ;SLC/KCM -- Utilities for HTTP communications ;Jun 20, 2022@12:21
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
 . I $L(ASC) S OUT=OUT_$ZCH($$HEX2DEC(ASC))
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
 I ERRCODE=401 S ERRNAME="Unauthorized"
 I ERRCODE=403 S ERRNAME="Forbidden"
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
 S HTTPERR("apiVersion")="1.1"
 S HTTPERR("error","code")=HTTPERR
 S HTTPERR("error","toperror")=TOPMSG
 S HTTPERR("error","request")=$G(HTTPREQ("method"))_" "_$G(HTTPREQ("path"))_" "_$G(HTTPREQ("query"))
 I $D(ERRARRAY) D
 . S HTTPERR("error","errors",HTTPERR("count"),"reason")=MESSAGE
 . M HTTPERR("error","errors",HTTPERR("count"),"message")=ERRARRAY  ; VEN/SMH
 E  D
 . S HTTPERR("error","errors",HTTPERR("count"),"reason")=ERRCODE
 . S HTTPERR("error","errors",HTTPERR("count"),"errname")=ERRNAME
 . S HTTPERR("error","errors",HTTPERR("count"),"message")=MESSAGE
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
