%ydbwebrsp ;SLC/KCM -- Handle HTTP Response;Jun 20, 2022@14:47
	;
	; -- prepare and send response
	;
respond ; find entry point to handle request and call it
	; expects httpreq, httprsp is used to return the response
	; HTTP variables are upper case since it gives end users the option
	; to use them as external references in their own code base.
	; They are also available in lower case for those interested.
	;
	new routine,location
	new httpargs,httploc
	;
	; Set-up upper-case aliases
	new HTTPREQ,HTTPARGS,HTTPRSP,HTTPLOC,HTTPERR,HTTPHASUSERS,HTTPREADWRITE
	;
	; Read-Only variables
	set *HTTPREQ=httpreq
	set *HTTPARGS=httpargs
	set *HTTPHASUSERS=httphasusers
	set *HTTPREADWRITE=httpreadwrite
	;
	if httpreq("path")="/",httpreq("method")="GET" do en^%ydbwebhome(.httprsp) quit  ; Home page requested.
	if httpreq("method")="OPTIONS" set httprsp="OPTIONS,POST" quit ; Always repond to OPTIONS to give CORS header info
	;
	; Resolve the URL and authenticate if necessary
	do match(.routine,.httpargs)
	;
	if $get(httperr)    quit  ; Error in matching
	if $order(httprsp(0)) quit  ; File on file system found matching path
	;
	; Split the query string
	do qsplit(httpreq("query"),.httpargs) if $get(httperr) quit
	;
	; %ydbnull opens /dev/null so that runtime routines can write out debugging information without it reaching the end user
	new %ydbnull set %ydbnull="/dev/null"
	open %ydbnull use %ydbnull
	;
	; httpreq("method") contains GET, POST, PUT, HEAD, or DELETE
	; httpreq("path") contains the path of the request (part from server to ?)
	; httpreq("query") contains any query params (part after ?)
	; httpreq("header",name) contains a node for each header value
	; httpreq("body",n) contains as an array the body of the request
	; httpreq("location") stashes the location value for PUT, POST
	;
	; httpargs is a key-value array of arguments in the server
	;
	; httprsp will contain the result of the operation. Most of the time you should put data in the format
	; httprsp(1)=..., httprsp(2)=...
	; You don't have to store this in order, and can have any structure, but this is not tested for.
	; You can set httprsp to a global, and it will get KILLED after it has been sent.

	; if httprsp("raw")=1, then @httprsp will be $queried for the output without
	; any transformations and the output will be sent as is.
	; httprsp("mime") will contain the mime type (default is application/json)
	; httprsp("ETag") contains the ETag. It's optional.
	; httprsp("pageable"): not currently implemented.
	; httploc contains the location of the new PUT/POST resource. It's put in httprsp("location").
	; 
	; If the httpreq("body") is actually JSON, convert it to an M array in httpreq("json")
	new %webjsonerror
	if $get(httpreq("header","content-type"))="application/json",$data(httpreq("body")) do
	. do decode^%ydbwebjson($name(httpreq("body")),$name(httpreq("json")),$name(%webjsonerror))
	. if $data(%webjsonerror) do setError^%ydbwebutils("201","JSON Converstion Error",.%webjsonerror)
	;
	if '$data(%webjsonerror) do
	. new httpoldgbldir,httpoldcwd,httpoldenv
	. ;
	. ; If a custom global directory is supplied, switch to that global directory
	. if $data(httpreq("header","x-ydb-global-directory")) set httpoldgbldir=$zgbldir new $zgbldir do
	.. set $zgbldir=httpreq("header","x-ydb-global-directory")
	.. view "setenv":"ydb_gbldir":httpreq("header","x-ydb-global-directory")
	.. do:httplog>0 stdout^%ydbwebutils("Using Alternate global directory "_$zgbldir)
	. ;
	. ; if a custom working directory is supplied, switch to that
	. if $data(httpreq("header","x-ydb-working-directory")) do
	.. do:httplog>0 stdout^%ydbwebutils("Using Alternate working directory "_$zdirectory)
	.. set httpoldcwd=$zdirectory
	.. set $zdirectory=httpreq("header","x-ydb-working-directory")
	. ;
	. ; If custom environment variables were requested
	. if $data(httpreq("header","x-ydb-env-vars")) do
	.. new i,var for i=1:1:$length(httpreq("header","x-ydb-env-vars"),";") do
	... set var=$$L^%TRIM($piece(httpreq("header","x-ydb-env-vars"),";",i))
	... new varname,varvalue
	... set varname=$piece(var,"=",1)
	... set varvalue=$piece(var,"=",2)
	... set httpoldenv(varname)=$ztrnlnm(varname)
	... do:httplog>0 stdout^%ydbwebutils("Setting Env Var "_varname_"="_varvalue)
	... view "setenv":varname:varvalue
	. ;
	. do @routine
	. ;
	. ; Restore the original values
	. if $data(httpoldgbldir) view "setenv":"ydb_gbldir":httpoldgbldir
	. if $data(httpoldcwd) set $zdirectory=httpoldcwd
	. if $data(httpoldenv) new v set v="" for  set v=$order(httpoldenv(v)) quit:v=""  view "setenv":v:httpoldenv(v)
	;
	; For data written out, if we have the upper case versions used by end users, point to them
	set:$data(HTTPRSP) *httprsp=HTTPRSP
	set:$data(HTTPLOC) *httploc=HTTPLOC
	set:$data(HTTPERR) *httperr=HTTPERR
	;
	if $get(httploc)'="" do
	. set httprsp("location")=$select($data(httpreq("header","host")):httpreq("header","host")_httploc,1:httploc)
	. if httpoptions("tlsconfig")'="" set httprsp("location")="https://"_httprsp("location")
	. else                            set httprsp("location")="http://"_httprsp("location")
	;
	; Back to our original device
	close %ydbnull use %ydbtcp
	quit
	;
qsplit(qparams,query) ; parses and decodes query fragment into array
	; expects qparams to contain "query" node
	; .query will contain query parameters as subscripts: query("name")=value
	new i,x,name,value
	for i=1:1:$length(qparams,"&") D
	. set x=$$urldec^%ydbwebutils($zpiece(qparams,"&",i))
	. set name=$zpiece(x,"="),value=$zpiece(x,"=",2,999)
	. if $length(name) set query($zconvert(name,"l"))=value
	quit
	;
match(routine,args) ; evaluate paths in sequence until match found (else 404)
	; Also does authentication and authorization
	; TODO: this needs some work so that it will accomodate patterns shorter than the path
	; expects httpreq to contain "path" and "method" nodes
	; routine contains the TAG^routine to execute for this path, otherwise empty
	; .args will contain an array of resolved path arguments
	;
	set routine=""  ; Default. Routine not found. Error 404.
	;
	; Using _ydbweburl.m
	new authneeded set authneeded=0 ; by default, no authorization needed
	;
	; Match against the %ydbweburl file
	DO matchr(.routine,.args,.authneeded)
	;
	; If that failed, try matching against a file on the file system
	; No authorization needed to serve web pages
	if routine="" set authneeded=0 DO matchfs(.routine)
	;
	; Okay. Do we have a routine to execute?
	if routine="" do setError^%ydbwebutils(404,"Not Found") quit
	;
	; If we need authorization, and we have users on the system...
	if authneeded,httphasusers do
	. new authenticated set authenticated=0
	. new timedout set timedout=0
	. ;
	. ; See if we have a token
	. if $get(httpreq("header","authorization"))'="" do
	.. new token set token=$zpiece(httpreq("header","authorization"),"Bearer ",2,99)
	.. ;
	.. ; If token is empty, don't continue
	.. if token="" quit
	.. ;
	.. ; If the token exists in our cache
	.. tstart ():transactionid="batch"
	..   if $$checkIfTokenExists^%ydbwebusers(token) do
	...   ; We are authenticated now
	...   set authenticated=1
	...   ;
	...   ; Check if token is expired
	...   if $$checkIfTokenIsExpired^%ydbwebusers(token) do  quit
	....   do stdout^%ydbwebutils("Token "_token_" timed out") 
	....   set timedout=1
	...   ;
	...   ; Update Token timeout
	...   do updateTokenTimeout^%ydbwebusers(token)
	...   ;
	...   ; Set User Authorization based on user data in the token cache
	...   if $$getAuthorizationFromToken^%ydbwebusers(token)="RW" set httpreadwrite=1
	...   else  set httpreadwrite=0
	...   ;
	.. tcommit
	. if 'authenticated do setError^%ydbwebutils(403,"Forbidden")     quit
	. if timedout       do setError^%ydbwebutils(408,"Token timeout") quit
	quit
	;
	;
matchr(routine,args,authneeded) ; Match against _ydbweburl.m
	new method set method=httpreq("method")
	if method="HEAD" set method="GET" ; just for here
	new path set path=httpreq("path")
	set:$extract(path)="/" path=$extract(path,2,$length(path))
	;
	; Special processing for ping, version, login, logout. They should be always available.
	set authneeded=0
	if method="GET",path="api/ping"      set routine="ping^%ydbwebapi" quit
	if method="GET",path="api/version"   set routine="version^%ydbwebapi" quit
	if method="POST",path="api/login"    set routine="login^%ydbwebapi" quit
	if method="GET",path="api/logout"   set routine="logout^%ydbwebapi" quit
	if method="GET",path="api/auth-mode" set routine="authmode^%ydbwebapi" quit
	;
	if $text(^%ydbweburl)="" set routine="" quit
	;
	; We probably want authorization to be part of the URL file; not global for all services.
	; Tracked by issue #118
	set authneeded=1
	;
	new seq,patmethod,fail
	new done set done=0
	for seq=1:1 set pattern=$zpiece($text(URLMAP+seq^%ydbweburl),";;",2,99) quit:pattern=""  quit:pattern="zzzzz"  do  quit:done
	. kill args
	. set routine=$zpiece(pattern," ",3),patmethod=$zpiece(pattern," "),pattern=$zpiece(pattern," ",2),fail=0
	. if $extract(pattern)="/" set pattern=$extract(pattern,2,$length(pattern))
	. if $length(pattern,"/")'=$length(path,"/") set routine="" quit  ; must have same number segments
	. for i=1:1:$length(path,"/") do  quit:fail
	. . set pathseg=$$urldec^%ydbwebutils($zpiece(path,"/",i),1)
	. . set pattseg=$$urldec^%ydbwebutils($zpiece(pattern,"/",i),1)
	. . if $extract(pattseg)'="{" set fail=($zconvert(pathseg,"l")'=$zconvert(pattseg,"l")) quit
	. . set pattseg=$extract(pattseg,2,$length(pattseg)-1) ; get rid of curly braces
	. . set argument=$zpiece(pattseg,"?"),test=$zpiece(pattseg,"?",2)
	. . if $length(test) set fail=(pathseg'?@test) quit:fail
	. . set args(argument)=pathseg
	. if 'fail if patmethod'=method set fail=1
	. set:fail routine="" set:'fail done=1
	quit
	;
matchfs(routine) ; Match against the file system
	new path set path=$extract(httpreq("path"),2,9999)
	do filesys^%ydbwebapi(path)
	if $order(httprsp(0)) set routine="filesys^%ydbwebapi"
	quit
	;
sendata ; write out the data as an HTTP response
	; expects httperr to contain the HTTP error code, if any
	; rsptype=1  local variable
	; rsptype=2  data in ^TMP($J)
	;
	new %ydbbuff set %ydbbuff="" ; Write Buffer
	;
	; DKM - Send raw data.
	if $get(httprsp("raw")) do  quit
	. new ary,x,l
	. set ary=$name(@httprsp),x=ary,l=$qlength(ary)
	. for  set x=$query(@x) quit:'$length(x)  quit:$name(@x,l)'=ary  do w(@x)
	. do flush
	. kill @ary
	;
	new size,rsptype,jsonout
	;
	; Set mime up, and auto-encode JSON if necessary
	if '$data(httprsp("mime")) set httprsp("mime")="application/json; charset=utf-8"
	if httprsp("mime")["application/json" D
	. kill httprsp("mime")
	. do encode^%ydbwebjson($name(httprsp),$name(jsonout),$name(%ydbjsonerror))
	. set *httprsp=jsonout
	. set httprsp("mime")="application/json; charset=utf-8"
	;
	new rspline set rspline=$$rspline()
	set rsptype=$select($extract($get(httprsp))'="^":1,$data(httprsp("pageable")):3,1:2)
	if rspline[304 set size=0 ; Not modified. Don't send data.
	else  D
	. if rsptype=1 set size=$$varsize^%ydbwebutils(.httprsp)
	. if rsptype=2 set size=$$refsize^%ydbwebutils(.httprsp)
	;
	; TODO: Handle 201 responses differently (change simple OK to created)
	;
	do w(rspline_$char(13,10)) ; Status Line (200, 404, etc)
	do w("Date: "_$$GMT^%ydbwebutils_$char(13,10)) ; RFC 1123 date
	if $data(httprsp("location")) do w("Location: "_httprsp("location")_$char(13,10))  ; Response Location
	if $data(httprsp("auth")) do w("WWW-Authenticate: "_httprsp("auth")_$char(13,10)) kill httprsp("auth") ; Authentication
	if $data(httprsp("ETag")) do w("ETag: "_httprsp("ETag")_$char(13,10)) kill httprsp("ETag") ; ETag
	if $data(httprsp("mime")) do w("Content-Type: "_httprsp("mime")_$char(13,10)) kill httprsp("mime") ; Mime type
	;
	; Add CORS Header
	if $get(httpreq("method"))="OPTIONS" do w("Access-Control-Allow-Methods: OPTIONS, POST"_$char(13,10))
	if $get(httpreq("method"))="OPTIONS" do w("Access-Control-Allow-Headers: Content-Type"_$char(13,10))
	if $get(httpreq("method"))="OPTIONS" do w("Access-Control-Max-Age: 86400"_$char(13,10))
	do w("Access-Control-Allow-Origin: *"_$char(13,10))
	;
	if httpoptions("gzip"),$get(httpreq("header","accept-encoding"))["gzip" goto gzip  ; If on GT.M, and we can zip, let's do that!
	;
	do w("Content-Length: "_size_$char(13,10)_$char(13,10))
	if 'size!(httpreq("method")="HEAD") do flush quit  ; flush buffer and quit if empty
	;
	new i,j
	if rsptype=1 do            ; write out local variable
	. if $data(httprsp)#2 do w(httprsp)
	. if $data(httprsp)>1 set i=0 for  set i=$order(httprsp(i)) quit:'i  do w(httprsp(i))
	;
	if rsptype=2 do            ; write out global using indirection
	. ; Write out the current node if valued
	. if $data(@httprsp)#2 do w(@httprsp)
	. ; If there are descendents...
	. if $data(@httprsp)>1 do
	. . ; Capture original for $query
	. . new orig,ol set orig=httprsp,ol=$qlength(httprsp) ; Orig, Orig Length
	. . new httpexit set httpexit=0
	. . for  do  quit:httpexit
	. . . set httprsp=$query(@httprsp)
	. . . if httprsp=""               set httpexit=1 quit
	. . . if $name(@httprsp,ol)'=orig set httpexit=1 quit
	. . . do w(@httprsp)
	. . set httprsp=orig
	. . ; Kill global after sending. https://github.com/shabiel/M-Web-Server/issues/44
	. . kill @httprsp
	do flush ; flush buffer
	quit
	;
w(data) ; EP to write data
	; ZEXCEPT: %ydbbuff - Buffer in Symbol Table
	if $zlength(%ydbbuff)+$zlength(data)>32000 do flush
	set %ydbbuff=%ydbbuff_data
	quit
	;
flush ; EP to flush written data
	; ZEXCEPT: %ydbbuff - Buffer in Symbol Table
	write %ydbbuff,!
	set %ydbbuff=""
	quit
	;
gzip ; EP to write gzipped content
	; Nothing to write?
	if 'size do  quit  ; nothing to write!
	. do w("Content-Length: 0"_$char(13,10,13,10))
	. do flush
	;
	; zip away - Open gzip and write to it, then read back the zipped file.
	new oldio set oldio=$io
	new file
	if $zversion["Linux" set file="/dev/shm/mws-"_$job_"-"_$random(999999)_".dat"
	else  set file="/tmp/mws-"_$job_"-"_$random(999999)_".dat"
	open file:(newversion:stream:nowrap:chset="M")
	use file
	;
	; Write out data
	new i,j
	if rsptype=1 do            ; write out local variable
	. if $data(httprsp)#2 write httprsp
	. if $data(httprsp)>1 set i=0 for  set i=$order(httprsp(i)) quit:'i  write httprsp(i)
	if rsptype=2 do            ; write out global using indirection
	. if $data(@httprsp)#2 write @httprsp
	. if $data(@httprsp)>1 set i=0 for  set i=$order(@httprsp@(i)) quit:'i  write @httprsp@(i)
	;
	; Close
	set $x=0 ; needed to prevent adding an EOF to the file
	close file
	;
	open "D":(shell="/bin/sh":command="gzip "_file:parse):0:"pipe"
	use "D" close "D"
	;
	new zipped
	open file_".gz":(readonly:fixed:nowrap:recordsize=255:chset="M"):0
	use file_".gz"
	new i for i=1:1 read zipped(i):0  quit:$zeof
	use oldio close file_".gz":delete
	;
	; Calculate new size (reset size first)
	set size=0
	new i for i=0:0 set i=$order(zipped(i)) quit:'i  set size=size+$zlength(zipped(i))
	;
	; Write out the content headings for gzipped file.
	do w("Content-Encoding: gzip"_$char(13,10))
	do w("Content-Length: "_size_$char(13,10)_$char(13,10))
	if httpreq("method")="HEAD" do flush quit  ; flush buffer and quit if empty
	;
	new i for i=0:0 set i=$order(zipped(i)) quit:'i  do w(zipped(i))
	do flush
	;
	quit
	;
rsperror ; set response to be an error response
	; Count is a temporary variable to track multiple errors... don't send it back
	; pageable is VPR code, not used, but kept for now.
	kill httperr("count"),httprsp("pageable")
	set *httprsp=httperr
	quit
	;
rspline() ; writes out a response line based on httperr
	if $data(httpreq("header","if-none-match")),$data(httprsp("ETag")) new OK set OK=0 do  quit:OK "HTTP/1.1 304 Not Modified"
	. if httpreq("header","if-none-match")=httprsp("ETag") set OK=1
	if '$get(httperr),'$data(httprsp("location")) quit "HTTP/1.1 200 OK"
	if '$get(httperr),$data(httprsp("location")) quit "HTTP/1.1 201 Created"
	if $get(httperr)=400 quit "HTTP/1.1 400 Bad Request"
	if $get(httperr)=401 quit "HTTP/1.1 401 Unauthorized"
	if $get(httperr)=403 quit "HTTP/1.1 403 Forbidden"
	if $get(httperr)=404 quit "HTTP/1.1 404 Not Found"
	if $get(httperr)=405 quit "HTTP/1.1 405 Method Not Allowed"
	if $get(httperr)=408 quit "HTTP/1.1 408 Request Timeout"
	quit "HTTP/1.1 500 Internal Server Error"
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright (c) 2013-2020 Sam Habiel
	; Copyright (c) 2018-2019 Christopher Edwards
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
