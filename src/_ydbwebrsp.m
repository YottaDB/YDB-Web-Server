%ydbwebrsp ;SLC/KCM -- Handle HTTP Response;Jun 20, 2022@14:47
 ;
 ; -- prepare and send RESPONSE
 ;
RESPOND ; find entry point to handle request and call it
 ; expects HTTPREQ, HTTPRSP is used to return the response
 ;
 N ROUTINE,LOCATION,HTTPARGS,HTTPLOC
 I HTTPREQ("path")="/",HTTPREQ("method")="GET" D en^%ydbwebhome(.HTTPRSP) QUIT  ; Home page requested.
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
 ; HTTPREQ("method") contains GET, POST, PUT, HEAD, or DELETE
 ; HTTPREQ("path") contains the path of the request (part from server to ?)
 ; HTTPREQ("query") contains any query params (part after ?)
 ; HTTPREQ("header",name) contains a node for each header value
 ; HTTPREQ("body",n) contains as an array the body of the request
 ; HTTPREQ("location") stashes the location value for PUT, POST
 ;
 ; HTTPARGS is a key-value array of arguments in the server
 ;
 ; HTTPRSP will contain the result of the operation. Most of the time you should put data in the format
 ; HTTPRSP(1)=..., HTTPRSP(2)=...
 ; You don't have to store this in order, and can have any structure, but this is not tested for.
 ; You can set HTTPRSP to a global, and it will get KILLED after it has been sent.

 ; if HTTPRSP("raw")=1, then @HTTPRSP will be $queried for the output without
 ; any transformations and the output will be sent as is.
 ; HTTPRSP("mime") will contain the mime type (default is application/json)
 ; HTTPRSP("ETag") contains the ETag. It's optional.
 ; HTTPRSP("pageable"): not currently implemented.
 ; HTTPLOC contains the location of the new PUT/POST resource. It's put in HTTPRSP("location").
 ; 
 ; Set-up lower-case aliases
 new httpreq,httpargs,httprsp,httploc
 set *httpreq=HTTPREQ
 set *httpargs=HTTPARGS
 set *httprsp=HTTPRSP
 set *httploc=HTTPLOC
 ;
 ; If the HTTPREQ("body") is actually JSON, convert it to an M array in HTTPREQ("json")
 new %webjsonerror
 if $get(httpreq("header","content-type"))="application/json",$data(httpreq("body")) do
 . do decode^%ydbwebjson($name(httpreq("body")),$name(httpreq("json")),$name(%webjsonerror))
 . if $data(%webjsonerror) do setError^%ydbwebutils("201","JSON Converstion Error",.%webjsonerror)
 ;
 if '$data(%webjsonerror) do @ROUTINE

 if $get(HTTPLOC)'="" do
 . S HTTPRSP("location")=$S($D(HTTPREQ("header","host")):HTTPREQ("header","host")_HTTPLOC,1:HTTPLOC)
 . if $get(TLSCONFIG)'="" set HTTPRSP("location")="https://"_HTTPRSP("location")
 . else                   set HTTPRSP("location")="http://"_HTTPRSP("location")
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
 . S X=$$URLDEC^%ydbwebutils($P(QPARAMS,"&",I))
 . S NAME=$P(X,"="),VALUE=$P(X,"=",2,999)
 . I $L(NAME) S QUERY($$LOW^%ydbwebutils(NAME))=VALUE
 Q
 ;
MATCH(ROUTINE,ARGS) ; evaluate paths in sequence until match found (else 404)
 ; Also does authentication and authorization
 ; TODO: this needs some work so that it will accomodate patterns shorter than the path
 ; expects HTTPREQ to contain "path" and "method" nodes
 ; ROUTINE contains the TAG^ROUTINE to execute for this path, otherwise empty
 ; .ARGS will contain an array of resolved path arguments
 ;
 S ROUTINE=""  ; Default. Routine not found. Error 404.
 ;
 ; Using _ydbweburl.m
 DO MATCHR(.ROUTINE,.ARGS)
 ;
 ; If that failed, try matching against a file on the file system
 I ROUTINE="" DO MATCHFS(.ROUTINE)
 ;
 ; Okay. Do we have a routine to execute?
 I ROUTINE="" D SETERROR^%ydbwebutils(404,"Not Found") QUIT
 ;
 I $G(USERPASS)'="" D
 . ; user must authenticate
 . S HTTPRSP("auth")="Basic realm="""_HTTPREQ("header","host")_"""" ; Send Authentication Header
 . N AUTHEN S AUTHEN=(USERPASS=$$DECODE64^%ydbwebutils($P($G(HTTPREQ("header","authorization"))," ",2))) ; Try to authenticate
 . I 'AUTHEN D SETERROR^%ydbwebutils(401,"Unauthorized") QUIT  ; Unauthoirzed
 QUIT
 ;
 ;
MATCHR(ROUTINE,ARGS) ; Match against _ydbweburl.m
 N METHOD S METHOD=HTTPREQ("method")
 I METHOD="HEAD" S METHOD="GET" ; just for here
 N PATH S PATH=HTTPREQ("path")
 S:$E(PATH)="/" PATH=$E(PATH,2,$L(PATH))
 ;
 ; Special processing for ping. It should be always available
 I METHOD="GET",PATH="ping" S ROUTINE="ping^%ydbwebapi" QUIT
 ;
 I $T(^%ydbweburl)="" S ROUTINE="" QUIT
 ;
 N SEQ,PATMETHOD
 N DONE S DONE=0
 F SEQ=1:1 S PATTERN=$P($T(URLMAP+SEQ^%ydbweburl),";;",2,99) Q:PATTERN=""  Q:PATTERN="zzzzz"  D  Q:DONE
 . K ARGS
 . S ROUTINE=$P(PATTERN," ",3),PATMETHOD=$P(PATTERN," "),PATTERN=$P(PATTERN," ",2),FAIL=0
 . I $E(PATTERN)="/" S PATTERN=$E(PATTERN,2,$L(PATTERN))
 . I $L(PATTERN,"/")'=$L(PATH,"/") S ROUTINE="" Q  ; must have same number segments
 . F I=1:1:$L(PATH,"/") D  Q:FAIL
 . . S PATHSEG=$$URLDEC^%ydbwebutils($P(PATH,"/",I),1)
 . . S PATTSEG=$$URLDEC^%ydbwebutils($P(PATTERN,"/",I),1)
 . . I $E(PATTSEG)'="{" S FAIL=($$LOW^%ydbwebutils(PATHSEG)'=$$LOW^%ydbwebutils(PATTSEG)) Q
 . . S PATTSEG=$E(PATTSEG,2,$L(PATTSEG)-1) ; get rid of curly braces
 . . S ARGUMENT=$P(PATTSEG,"?"),TEST=$P(PATTSEG,"?",2)
 . . I $L(TEST) S FAIL=(PATHSEG'?@TEST) Q:FAIL
 . . S ARGS(ARGUMENT)=PATHSEG
 . I 'FAIL I PATMETHOD'=METHOD S FAIL=1
 . S:FAIL ROUTINE="" S:'FAIL DONE=1
 QUIT
 ;
MATCHFS(ROUTINE) ; Match against the file system
 N PATH S PATH=$E(HTTPREQ("path"),2,9999)
 D FILESYS^%ydbwebapi(PATH)
 I $O(HTTPRSP(0)) S ROUTINE="FILESYS^%ydbwebapi"
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
 ;
 N SIZE,RSPTYPE,PREAMBLE,START,LIMIT,JSONOUT
 ;
 ; Set mime up, and auto-encode JSON if necessary
 I '$D(HTTPRSP("mime")) set HTTPRSP("mime")="application/json; charset=utf-8"
 I HTTPRSP("mime")["application/json" D
 . kill HTTPRSP("mime")
 . do encode^%ydbwebjson($name(HTTPRSP),$name(JSONOUT),$name(%ydbjsonerror))
 . set *HTTPRSP=JSONOUT
 . set HTTPRSP("mime")="application/json; charset=utf-8"
 ;
 N RSPLINE S RSPLINE=$$RSPLINE()
 S RSPTYPE=$S($E($G(HTTPRSP))'="^":1,$D(HTTPRSP("pageable")):3,1:2)
 I RSPLINE[304 S SIZE=0 ; Not modified. Don't send data.
 E  D
 . I RSPTYPE=1 S SIZE=$$VARSIZE^%ydbwebutils(.HTTPRSP)
 . I RSPTYPE=2 S SIZE=$$REFSIZE^%ydbwebutils(.HTTPRSP)
 ;
 ; TODO: Handle 201 responses differently (change simple OK to created)
 ;
 D W(RSPLINE_$C(13,10)) ; Status Line (200, 404, etc)
 D W("Date: "_$$GMT^%ydbwebutils_$C(13,10)) ; RFC 1123 date
 I $D(HTTPRSP("location")) D W("Location: "_HTTPRSP("location")_$C(13,10))  ; Response Location
 I $D(HTTPRSP("auth")) D W("WWW-Authenticate: "_HTTPRSP("auth")_$C(13,10)) K HTTPRSP("auth") ; Authentication
 I $D(HTTPRSP("ETag")) D W("ETag: "_HTTPRSP("ETag")_$C(13,10)) K HTTPRSP("ETag") ; ETag
 I $D(HTTPRSP("mime")) D W("Content-Type: "_HTTPRSP("mime")_$C(13,10)) K HTTPRSP("mime") ; Mime type
 ;
 ; Add CORS Header
 I $G(HTTPREQ("method"))="OPTIONS" D W("Access-Control-Allow-Methods: OPTIONS, POST"_$C(13,10))
 I $G(HTTPREQ("method"))="OPTIONS" D W("Access-Control-Allow-Headers: Content-Type"_$C(13,10))
 I $G(HTTPREQ("method"))="OPTIONS" D W("Access-Control-Max-Age: 86400"_$C(13,10))
 D W("Access-Control-Allow-Origin: *"_$C(13,10))
 ;
 I GZIP,$G(HTTPREQ("header","accept-encoding"))["gzip" GOTO GZIP  ; If on GT.M, and we can zip, let's do that!
 ;
 D W("Content-Length: "_SIZE_$C(13,10)_$C(13,10))
 I 'SIZE!(HTTPREQ("method")="HEAD") D FLUSH Q  ; flush buffer and quit if empty
 ;
 ; Auto encode to JSON?
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
 S *HTTPRSP=HTTPERR
 Q
 ;
RSPLINE() ; writes out a response line based on HTTPERR
 I $D(HTTPREQ("header","if-none-match")),$D(HTTPRSP("ETag")) N OK S OK=0 D  Q:OK "HTTP/1.1 304 Not Modified"
 . I HTTPREQ("header","if-none-match")=HTTPRSP("ETag") S OK=1
 I '$G(HTTPERR),'$D(HTTPRSP("location")) Q "HTTP/1.1 200 OK"
 I '$G(HTTPERR),$D(HTTPRSP("location")) Q "HTTP/1.1 201 Created"
 I $G(HTTPERR)=400 Q "HTTP/1.1 400 Bad Request"
 I $G(HTTPERR)=401 Q "HTTP/1.1 401 Unauthorized"
 I $G(HTTPERR)=404 Q "HTTP/1.1 404 Not Found"
 I $G(HTTPERR)=405 Q "HTTP/1.1 405 Method Not Allowed"
 Q "HTTP/1.1 500 Internal Server Error"
 ;
 ; Portions of this code are public domain, but it was extensively modified
 ; Copyright (c) 2013-2020 Sam Habiel
 ; Copyright (c) 2018-2019 Christopher Edwards
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
