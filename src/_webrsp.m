%webrsp ;SLC/KCM -- Handle HTTP Response;Jun 20, 2022@14:47
 ;
 ; -- prepare and send RESPONSE
 ;
RESPOND ; find entry point to handle request and call it
 ; expects HTTPREQ, HTTPRSP is used to return the response
 ;
 N ROUTINE,LOCATION,HTTPARGS,HTTPBODY
 I HTTPREQ("path")="/",HTTPREQ("method")="GET" D en^%webhome(.HTTPRSP) QUIT  ; Home page requested.
 I HTTPREQ("method")="OPTIONS" S HTTPRSP="OPTIONS,POST" QUIT ; Always repond to OPTIONS to give CORS header info
 ;
 ; Resolve the URL and authenticate if necessary
 D MATCH(.ROUTINE,.HTTPARGS)
 ;
 I $G(HTTPERR)    QUIT  ; Error in matching
 I $O(HTTPRSP(0)) QUIT  ; File on file system found matching path
 ;
 ; Split the query string
 D QSPLIT(HTTPREQ("query"),.HTTPARGS) I $G(HTTPERR) QUIT
 ;
 ; %WNULL opens /dev/null so that runtime routines can write out debugging information without it reaching the end user
 N %WNULL S %WNULL="/dev/null"
 O %WNULL U %WNULL
 ;
 N BODY M BODY=HTTPREQ("body") K HTTPREQ("body")
 ;
 ; r will contain the routine to execute
 n r
 if "PUT,POST"[HTTPREQ("method") do 
 . set r=ROUTINE_"(.HTTPARGS,.BODY,.HTTPRSP)"
 . xecute "S LOCATION=$$"_r
 else  set r=ROUTINE_"(.HTTPRSP,.HTTPARGS)" do @r
 ;
 if $get(LOCATION)'="" do
 . S HTTPREQ("location")=$S($D(HTTPREQ("header","host")):HTTPREQ("header","host")_LOCATION,1:LOCATION)
 . if $get(TLSCONFIG)'="" set HTTPREQ("location")="https://"_HTTPREQ("location")
 . else                   set HTTPREQ("location")="http://"_HTTPREQ("location")
 ;
 ; Back to our original device
 C %WNULL U %WTCP
 Q
 ;
QSPLIT(QPARAMS,QUERY) ; parses and decodes query fragment into array
 ; expects QPARAMS to contain "query" node
 ; .QUERY will contain query parameters as subscripts: QUERY("name")=value
 N I,X,NAME,VALUE
 F I=1:1:$L(QPARAMS,"&") D
 . S X=$$URLDEC^%webutils($P(QPARAMS,"&",I))
 . S NAME=$P(X,"="),VALUE=$P(X,"=",2,999)
 . I $L(NAME) S QUERY($$LOW^%webutils(NAME))=VALUE
 Q
 ;
MATCH(ROUTINE,ARGS) ; evaluate paths in sequence until match found (else 404)
 ; Also does authentication and authorization
 ; TODO: this needs some work so that it will accomodate patterns shorter than the path
 ; expects HTTPREQ to contain "path" and "method" nodes
 ; ROUTINE contains the TAG^ROUTINE to execute for this path, otherwise empty
 ; .ARGS will contain an array of resolved path arguments
 ;  - PUT/POST (.HTTPARGS,.BODY,.HTTPRSP)
 ;  - HEAD/GET/DELETE (.HTTPRSP,.HTTPARGS)
 ;
 S ROUTINE=""  ; Default. Routine not found. Error 404.
 ;
 ; Using _weburl.m
 DO MATCHR(.ROUTINE,.ARGS)
 ;
 ; If that failed, try matching against a file on the file system
 I ROUTINE="" DO MATCHFS(.ROUTINE)
 ;
 ; Okay. Do we have a routine to execute?
 I ROUTINE="" D SETERROR^%webutils(404,"Not Found") QUIT
 ;
 I $G(USERPASS)'="" D
 . ; user must authenticate
 . S HTTPRSP("auth")="Basic realm="""_HTTPREQ("header","host")_"""" ; Send Authentication Header
 . N AUTHEN S AUTHEN=(USERPASS=$$DECODE64^%webutils($P($G(HTTPREQ("header","authorization"))," ",2))) ; Try to authenticate
 . I 'AUTHEN D SETERROR^%webutils(401) QUIT  ; Unauthoirzed
 QUIT
 ;
 ;
MATCHR(ROUTINE,ARGS) ; Match against _weburl.m
 I $T(^%weburl)="" S ROUTINE="" QUIT
 ;
 N METHOD S METHOD=HTTPREQ("method")
 I METHOD="HEAD" S METHOD="GET" ; just for here
 N PATH S PATH=HTTPREQ("path")
 S:$E(PATH)="/" PATH=$E(PATH,2,$L(PATH))
 N SEQ,PATMETHOD
 N DONE S DONE=0
 F SEQ=1:1 S PATTERN=$P($T(URLMAP+SEQ^%weburl),";;",2,99) Q:PATTERN=""  Q:PATTERN="zzzzz"  D  Q:DONE
 . K ARGS
 . S ROUTINE=$P(PATTERN," ",3),PATMETHOD=$P(PATTERN," "),PATTERN=$P(PATTERN," ",2),FAIL=0
 . I $E(PATTERN)="/" S PATTERN=$E(PATTERN,2,$L(PATTERN))
 . I $L(PATTERN,"/")'=$L(PATH,"/") S ROUTINE="" Q  ; must have same number segments
 . F I=1:1:$L(PATH,"/") D  Q:FAIL
 . . S PATHSEG=$$URLDEC^%webutils($P(PATH,"/",I),1)
 . . S PATTSEG=$$URLDEC^%webutils($P(PATTERN,"/",I),1)
 . . I $E(PATTSEG)'="{" S FAIL=($$LOW^%webutils(PATHSEG)'=$$LOW^%webutils(PATTSEG)) Q
 . . S PATTSEG=$E(PATTSEG,2,$L(PATTSEG)-1) ; get rid of curly braces
 . . S ARGUMENT=$P(PATTSEG,"?"),TEST=$P(PATTSEG,"?",2)
 . . I $L(TEST) S FAIL=(PATHSEG'?@TEST) Q:FAIL
 . . S ARGS(ARGUMENT)=PATHSEG
 . I 'FAIL I PATMETHOD'=METHOD S FAIL=1
 . S:FAIL ROUTINE="" S:'FAIL DONE=1
 QUIT
 ;
MATCHFS(ROUTINE) ; Match against the file system
 N ARGS S ARGS("*")=$E(HTTPREQ("path"),2,9999)
 D FILESYS^%webapi(.HTTPRSP,.ARGS)
 I $O(HTTPRSP(0)) S ROUTINE="FILESYS^%webapi"
 quit
 ;
SENDATA ; write out the data as an HTTP response
 ; expects HTTPERR to contain the HTTP error code, if any
 ; RSPTYPE=1  local variable
 ; RSPTYPE=2  data in ^TMP($J)
 ;
 N %WBUFF S %WBUFF="" ; Write Buffer
 ;
 ; DKM - Send raw data.
 I $G(HTTPRSP("raw")) D  Q
 . N ARY,X,L
 . S ARY=$NA(@HTTPRSP),X=ARY,L=$QL(ARY)
 . F  S X=$Q(@X) Q:'$L(X)  Q:$NA(@X,L)'=ARY  D W(@X)
 . D FLUSH
 . K @ARY
 N SIZE,RSPTYPE,PREAMBLE,START,LIMIT
 S RSPTYPE=$S($E($G(HTTPRSP))'="^":1,$D(HTTPRSP("pageable")):3,1:2)
 I RSPTYPE=1 S SIZE=$$VARSIZE^%webutils(.HTTPRSP)
 I RSPTYPE=2 S SIZE=$$REFSIZE^%webutils(.HTTPRSP)
 ;
 ; TODO: Handle 201 responses differently (change simple OK to created)
 ;
 D W($$RSPLINE()_$C(13,10)) ; Status Line (200, 404, etc)
 D W("Date: "_$$GMT^%webutils_$C(13,10)) ; RFC 1123 date
 I $D(HTTPREQ("location")) D W("Location: "_HTTPREQ("location")_$C(13,10))  ; Response Location
 I $D(HTTPRSP("auth")) D W("WWW-Authenticate: "_HTTPRSP("auth")_$C(13,10)) K HTTPRSP("auth") ; Authentication
 I $D(HTTPRSP("cache")) D W("Cache-Control: max-age="_HTTPRSP("cache")_$C(13,10)) K HTTPRSP("cache") ; Browser caching
 I $D(HTTPRSP("mime")) D  ; Stack $TEST for the ELSE below
 . D W("Content-Type: "_HTTPRSP("mime")_$C(13,10)) K HTTPRSP("mime") ; Mime-type
 E  D W("Content-Type: application/json; charset=utf-8"_$C(13,10))
 ;
 ; Add CORS Header
 I $G(HTTPREQ("method"))="OPTIONS" D W("Access-Control-Allow-Methods: OPTIONS, POST"_$C(13,10))
 I $G(HTTPREQ("method"))="OPTIONS" D W("Access-Control-Allow-Headers: Content-Type"_$C(13,10))
 I $G(HTTPREQ("method"))="OPTIONS" D W("Access-Control-Max-Age: 86400"_$C(13,10))
 D W("Access-Control-Allow-Origin: *"_$C(13,10))
 ;
 I 'NOGZIP,$G(HTTPREQ("header","accept-encoding"))["gzip" GOTO GZIP  ; If on GT.M, and we can zip, let's do that!
 ;
 D W("Content-Length: "_SIZE_$C(13,10)_$C(13,10))
 I 'SIZE!(HTTPREQ("method")="HEAD") D FLUSH Q  ; flush buffer and quit if empty
 ;
 N I,J
 I RSPTYPE=1 D            ; write out local variable
 . I $D(HTTPRSP)#2 D W(HTTPRSP)
 . I $D(HTTPRSP)>1 S I=0 F  S I=$O(HTTPRSP(I)) Q:'I  D W(HTTPRSP(I))
 I RSPTYPE=2 D            ; write out global using indirection
 . I $D(@HTTPRSP)#2 D W(@HTTPRSP)
 . I $D(@HTTPRSP)>1 D
 . . N ORIG,OL S ORIG=HTTPRSP,OL=$QL(HTTPRSP) ; Orig, Orig Length
 . . N HTTPEXIT S HTTPEXIT=0
 . . F  D  Q:HTTPEXIT
 . . . S HTTPRSP=$Q(@HTTPRSP)
 . . . D:$G(HTTPRSP)'="" W(@HTTPRSP)
 . . . I $G(HTTPRSP)="" S HTTPEXIT=1
 . . . E  I $G(@HTTPRSP),$G(@ORIG),$NA(@HTTPRSP,OL)'=$NA(@ORIG,OL) S HTTPEXIT=1
 . . S HTTPRSP=ORIG
 . . ; Kill global after sending. https://github.com/shabiel/M-Web-Server/issues/44
 . . K @HTTPRSP
 D FLUSH ; flush buffer
 Q
 ;
W(DATA) ; EP to write data
 ; ZEXCEPT: %WBUFF - Buffer in Symbol Table
 I $ZL(%WBUFF)+$ZL(DATA)>32000 D FLUSH
 S %WBUFF=%WBUFF_DATA
 QUIT
 ;
FLUSH ; EP to flush written data
 ; ZEXCEPT: %WBUFF - Buffer in Symbol Table
 W %WBUFF,!
 S %WBUFF=""
 QUIT
 ;
GZIP ; EP to write gzipped content
 ; Nothing to write?
 I 'SIZE D  QUIT  ; nothing to write!
 . D W("Content-Length: 0"_$C(13,10,13,10))
 . D FLUSH
 ;
 ; zip away - Open gzip and write to it, then read back the zipped file.
 N OLDIO S OLDIO=$IO
 n file
 i $ZV["Linux" s file="/dev/shm/mws-"_$J_"-"_$R(999999)_".dat"
 e  s file="/tmp/mws-"_$J_"-"_$R(999999)_".dat"
 o file:(newversion:stream:nowrap:chset="M")
 u file
 ;
 ; Write out data
 N I,J
 I RSPTYPE=1 D            ; write out local variable
 . I $D(HTTPRSP)#2 W HTTPRSP
 . I $D(HTTPRSP)>1 S I=0 F  S I=$O(HTTPRSP(I)) Q:'I  W HTTPRSP(I)
 I RSPTYPE=2 D            ; write out global using indirection
 . I $D(@HTTPRSP)#2 W @HTTPRSP
 . I $D(@HTTPRSP)>1 S I=0 F  S I=$O(@HTTPRSP@(I)) Q:'I  W @HTTPRSP@(I)
 ;
 ; Close
 s $x=0 ; needed to prevent adding an EOF to the file
 c file
 ;
 O "D":(shell="/bin/sh":command="gzip "_file:parse):0:"pipe"
 U "D" C "D"
 ;
 n ZIPPED
 o file_".gz":(readonly:fixed:nowrap:recordsize=255:chset="M"):0
 u file_".gz"
 n i f i=1:1 read ZIPPED(i):0  q:$zeof
 U OLDIO c file_".gz":delete
 ;
 ; Calculate new size (reset SIZE first)
 S SIZE=0
 N I F I=0:0 S I=$O(ZIPPED(I)) Q:'I  S SIZE=SIZE+$ZL(ZIPPED(I))
 ;
 ; Write out the content headings for gzipped file.
 D W("Content-Encoding: gzip"_$C(13,10))
 D W("Content-Length: "_SIZE_$C(13,10)_$C(13,10))
 I HTTPREQ("method")="HEAD" D FLUSH Q  ; flush buffer and quit if empty
 ;
 N I F I=0:0 S I=$O(ZIPPED(I)) Q:'I  D W(ZIPPED(I))
 D FLUSH
 ;
 QUIT
 ;
RSPERROR ; set response to be an error response
 ; Count is a temporary variable to track multiple errors... don't send it back
 ; pageable is VPR code, not used, but kept for now.
 K HTTPERR("count"),HTTPRSP("pageable")
 D encode^%webjson($NAME(HTTPERR),$NAME(HTTPRSP))
 Q
RSPLINE() ; writes out a response line based on HTTPERR
 ; VEN/SMH: TODO: There ought to be a simpler way to do this!!!
 I '$G(HTTPERR),'$D(HTTPREQ("location")) Q "HTTP/1.1 200 OK"
 I '$G(HTTPERR),$D(HTTPREQ("location")) Q "HTTP/1.1 201 Created"
 I $G(HTTPERR)=400 Q "HTTP/1.1 400 Bad Request"
 I $G(HTTPERR)=401 Q "HTTP/1.1 401 Unauthorized"
 I $G(HTTPERR)=404 Q "HTTP/1.1 404 Not Found"
 I $G(HTTPERR)=405 Q "HTTP/1.1 405 Method Not Allowed"
 Q "HTTP/1.1 500 Internal Server Error"
 ;
 ; Portions of this code are public domain, but it was extensively modified
 ; Copyright (c) 2013-2020 Sam Habiel
 ; Copyright (c) 2018-2019 Christopher Edwards
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
