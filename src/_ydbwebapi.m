%ydbwebapi ; OSE/SMH - Infrastructure web services hooks;Jun 20, 2022@14:45
	;
routine ; GET /test/r/{routine} Mumps Routine
	set httprsp("mime")="text/plain; charset=utf-8"
	new rtn set rtn=$get(httpargs("routine"))
	new off,i,ln,ln0
	if rtn]""&($text(^@rtn)]"") for i=1:1 set off="+"_i,ln0=off_"^"_rtn,ln=$text(@ln0) quit:ln=""  set httprsp(i)=ln_$char(13,10)
	else  kill httprsp("mime") do setError^%ydbwebutils(404,"Routine not found")
	quit
	;
putroutine ; PUT /test/r/{routine} Mumps Routine
	new parsed ; Parsed array which stores each line on a separate node.
	new body merge body=httpreq("body")
	do parse10^%ydbwebutils(.body,.parsed) ; Parser
	new die,xcn set die="parsed(",xcn=0
	new rn set rn=httpargs("routine")
	quit:$extract(rn,1,4)'="KBAN"  ; Just for this server, don't do this.
	new %,%F,%I,%N,$etrap
	set $etrap="set $ecode="""" quit"
	set %I=$io
	set %F=$zpiece($$SRCDIR^%RSEL," ")_"/"_$translate(rn,"%","_")_".m"
	open %F:newversion use %F
	for  set xcn=$O(@(die_xcn_")")) quit:xcn'>0  set %=@(die_xcn_")") quit:$extract(%,1)="$"  if $extract(%)'=";" write %,!
	close %F
	zlink rn
	use %I
	set httploc="/test/r/"_rn
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	QUIT
	;
err ; GET /test/error Force M Error
	if $get(httpargs("foo"))="crash2" set %webcrash2=1 ; crash the error trap
	do err1
	QUIT
err1 ;
	new x set x=1/0
	;
bigoutput ; GET /test/bigoutput - Used by Unit Tests to ensure large output is handled appropriately
	new a,b,c
	set $zpiece(a,"a",2**10)="a"
	new i for i=1:1:32 set httprsp(i)=a
	set httprsp(32)=$extract(httprsp(32),1,$length(httprsp(32))-1)
	set b=$char(13,10)
	set httprsp(33)=b
	set httprsp("mime")="text/plain; charset=utf-8" ; type of data to send browser
	quit
	;
gloreturn1 ; GET /test/gloreturn1 - Used by Unit Tests to ensure Global deleted properly and $query works
	set httprsp=$name(^web1("%ydbwebapi"))
	set @httprsp="coo"_$char(13,10)
	set @httprsp@(1)="boo"_$char(13,10)
	set @httprsp@(2)="foo"_$char(13,10)
	set ^web1("z")="WRONG DATA"
	set httprsp("mime")="text/plain; charset=utf-8" ; type of data to send browser
	quit
	;
gloreturn2 ; GET /test/gloreturn2 - Used by Unit Tests to ensure $query works on empty subscript
	set httprsp=$name(^web2)
	set @httprsp="coo"_$char(13,10)
	set @httprsp@(1)="boo"_$char(13,10)
	set @httprsp@(2)="foo"_$char(13,10)
	set httprsp("mime")="text/plain; charset=utf-8" ; type of data to send browser
	quit
	;
gloreturn3 ; GET /test/gloreturn3 - Used by Unit Tests to ensure a single global is killed
	set httprsp=$name(^web3)
	set @httprsp="foo"_$char(13,10)
	set httprsp("mime")="text/plain; charset=utf-8" ; type of data to send browser
	quit
	;
utf8get ; GET /test/utf8/get
	set httprsp=httpargs("foo")
	set httprsp("mime")="text/plain; charset=UTF-8"
	quit
	;
utf8post ; POST /test/utf8/post
	new output
	do decode^%ydbwebjson($na(httpreq("body")),$na(output))
	set httprsp(1)=$extract(httpargs("foo"),1,3)_$char(13,10)
	set httprsp(2)=$get(httpreq("json","直接"))
	set httprsp("mime")="text/plain; charset=UTF-8"
	set httploc="test/utf8/post?foo="_httpargs("foo")
	quit
	;
ping ; GET /api/ping writes out a ping response
	set httprsp("self")=$job
	set httprsp("self","\s")=""
	set httprsp("server")=httpparentpid
	set httprsp("server","\s")=""
	quit
	;
version ; GET /api/version returns version information
	set httprsp("version")=$$version^%ydbwebversion
	quit
	;
login ; POST /api/login { "username": "xxx", "password": "pass" }
	new username set username=$get(httpreq("json","username"))
	new password set password=$get(httpreq("json","password"))
	if (username="")!(password="") do setError^%ydbwebutils(401,"Unauthorized") QUIT
	;
	tstart ():transactionid="batch"
	  if $$checkIfUserExists^%ydbwebusers(username,password) do
	  . new authorization,token
	  . set token=$$generateToken^%ydbwebusers(username)
	  . set authorization=$$getAuthorizationFromUser^%ydbwebusers(username)
	  . do storeToken^%ydbwebusers(token,authorization)
	  . set httprsp("token")=token
	  . set httprsp("authorization")=authorization
	  . set httprsp("timeout")=(httpttimeout/1000/1000)
	  else  do setError^%ydbwebutils(401,"Unauthorized")  ; Invalid
	tcommit
	quit
	;
logout ; POST /api/logout (with token in the header)
	new token set token=$zpiece($get(httpreq("header","authorization")),"Bearer ",2,99)
	tstart ():transactionid="batch"
	  if token'="",$$checkIfTokenExists^%ydbwebusers(token) do
	  . do deleteToken^%ydbwebusers(token)
	  . set httprsp("status")="OK"
	  else  set httprsp("status")="token not found"
	tcommit
	quit
	;
authmode ; GET /api/auth-mode
	set httprsp("auth")=$select(HTTPHASUSERS:"true",1:"false")
	quit
	;
xml ; GET /test/xml XML sample
	set httprsp("mime")="text/xml"
	set httprsp(1)="<?xml version=""1.0"" encoding=""UTF-8""?>"
	set httprsp(2)="<note>"
	set httprsp(3)="<to>Tovaniannnn</to>"
	set httprsp(4)="<from>Jani</from>"
	set httprsp(5)="<heading>Reminders</heading>"
	set httprsp(6)="<body>Don't forget me this weekend!</body>"
	set httprsp(7)="</note>"
	QUIT
	;
getjson ; GET /test/json JSON sample
	set httprsp("foo",1)="boo"
	set httprsp("foo",2)="doo"
	set httprsp("foo",3)="loo"
	quit
	;
customerr ; GET /test/customerror custom error sample
	new errarr
	set errarr("resourceType")="OperationOutcome"
	set errarr("issue",1,"severity")="error"
	set errarr("issue",1,"code")="processing"
	set errarr("issue",1,"diagnostics")="Test message"
	do customError^%ydbwebutils(400,.errarr)
	quit
	;
empty(r,a) ; GET /test/empty. Used For Unit Tests
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set r=""
	quit
	;
posttest ; POST /test/post Simple test for post
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp="/path/"_httpreq("json","random")_"/1" ; Stored URL
	set httploc=httprsp
	quit
	;
chunkedpost ; POST /test/postchunked Test for Chunked data
	; returns length of body and number of nodes that we stored the data in
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	new l set l=0
	new i for i=0:0 set i=$order(httpreq("body",i)) quit:'i  set l=l+$zlength(httpreq("body",i))
	new last set last=$order(httpreq("body",""),-1)
	set httprsp=l_"^"_+last
	quit
	;
chunkedpostincread ; Incremental read of each chunk
	new l set l=0
	new i for i=0:0 set i=$order(httpreq("body",i)) quit:'i  set l=l+$zlength(httpreq("body",i))
	new last set last=$order(httpreq("body",""),-1)
	set chunkedread($i(chunkedread))=l_"^"_+last
	quit
	;
chunkedpostinc ; POST /text/postchunkedinc Incremental Read Chunk Test
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	new i for i=0:0 set i=$order(chunkedread(i)) quit:'i  set httprsp(i)=chunkedread(i)_$char(13,10)
	quit	
	;
chunkedget ; GET /test/getchunked Test for Chunked data
	set data1="data1"
	set data2="data2"_$char(13,10)
	set ^data3="global_data3"
	set ^data4="global_data4"_$char(13,10)
	set ^data5="global_multiple_nodes_query: "
	set ^data5(1)="subnode1"
	set ^data5(2)="subnode2"
	set ^data5(3)=$char(13,10)
	set ^data6("foo",1)="global_sequential_nodes_query: "
	set ^data6("foo",2)="subnode1"
	set ^data6("foo",3)="subnode2"
	set ^data6("foo",4)=$char(13,10)
	set ^data6("goo")="SHOULD NOT BE SENT"_$char(13,10)
	set ^data9="End of Transmission"_$char(13,10)
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp("chunked",1)=$name(data1)
	set httprsp("chunked",2)=$name(data2)
	set httprsp("chunked",3)=$name(^data3)
	set httprsp("chunked",4)=$name(^data4)
	set httprsp("chunked",5)=$name(^data5)
	set httprsp("chunked",6)=$name(^data6("foo"))
	set httprsp("chunked",7)="chunkcallback1^"_$text(+0)
	set httprsp("chunked",8)="chunkcallback2^"_$text(+0)
	set httprsp("chunked",9)=$name(^data9)
	quit
	;
chunkcallback1 ; Test Callback for the writing a single large chunk
	new oldio set oldio=$io
	; This file was chosen for testing as that exercises flush^%ydbwebrsp because it's larger than 32k
	new file set file="/mwebserver/r/_ydbwebtest.m"
	; Get file size
	open "D":(shell="/bin/sh":command="stat -c%s "_file:parse):0:"pipe"
	use "D"
	new size read size
	use oldio close "D"
	;
	; Send hex size
	do:httplog>2 stdout^%ydbwebutils("Sending chunk with size "_size)
	new hexsize set hexsize=$$dec2hex^%ydbwebutils(size)
	do w^%ydbwebrsp(hexsize_$char(13,10))
	;
	; read and send file
	; Fixed prevents Reads to terminators on SD's. CHSET makes sure we don't analyze UTF.
	open file:(rewind:readonly:fixed:chset="M")
	use file
	; hang simulates that we are sending lots of data slowly
	new x for  read x#4079:0 use oldio do w^%ydbwebrsp(x) hang .01 use file quit:$zeof
	use oldio close file
	; now send end of this chunk (CRLF)
	do w^%ydbwebrsp($char(13,10))
	quit
	;
chunkcallback2 ; Test Callback for writing multiple small chunks
	new oldio set oldio=$io
	; This file was chosen for testing as that exercises flush^%ydbwebrsp because it's larger than 32k
	new file set file="/mwebserver/r/_ydbwebtest.m"
	;
	; Get file size (for verifying that we sent the full file)
	open "D":(shell="/bin/sh":command="stat -c%s "_file:parse):0:"pipe"
	use "D"
	new fullsize read fullsize
	use oldio close "D"
	;
	; read and send file in chunks
	; Fixed prevents Reads to terminators on SD's. CHSET makes sure we don't analyze UTF.
	open file:(rewind:readonly:fixed:chset="M":nowrap)
	use file
	new incsize,size set incsize=0
	new x for  read x#4079:0 quit:$zeof  set size=$$sendonechunk^%ydbwebrsp(x),incsize=incsize+size
	use oldio close file
	do:httplog>2 stdout^%ydbwebutils("full size: "_fullsize_" sent size: "_incsize)
	if fullsize'=incsize set $ecode=",U-signal-error,"
	quit
	;
readwritetest ; GET /test/readwrite Tests readwrite flag
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=HTTPREADWRITE ; 0 or 1
	quit
	;
simtimeout ; GET /test/simtimeout Simulate Timeout
	; This artifically expires the current token so that we can see that we time out when we re-use it
	new token set token=$zpiece(HTTPREQ("header","authorization"),"Bearer ",2,99)
	new oldut set oldut=$zpiece(^|httpwebgld|tokens(token),"^")
	new newut set newut=oldut-httpttimeout-60
	set $zpiece(^|httpwebgld|tokens(token),"^")=newut
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=oldut_"^"_newut_$char(10,13)
	quit
	;
simsodiumerr ; GET /test/simsodiumerr Simulate libsodium runtime error
	new oldxc set oldxc=$ztrnlnm("ydb_xc_sodium")
	view "setenv":"ydb_xc_sodium":"/tmp/i/dont/exist.xc"
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=$$generateToken^%ydbwebusers("foo")
	view "setenv":"ydb_xc_sodium":oldxc
	quit
	;
uppercase ; GET /test/uppercase Use upper case variables
	new args merge args=HTTPARGS
	set HTTPRSP("mime")="text/plain"
	set HTTPRSP=@$query(args)
	quit
	;
globaldir ; GET /test/zgbldir Test X-YDB-Global-Directory
	if $get(httpargs("crash"))=1 set $ecode=",USIMERR,"
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	if $zgbldir'="" set ^x=1 ; This ensures that we actually write to a database (the old value only applies if no database directory has been set-up)
	set httprsp=$zgbldir_"|"_$ztrnlnm("ydb_gbldir")
	quit
	;
cwd	; GET /test/cwd Test X-YDB-Working-Directory
	if $get(httpargs("crash"))=1 set $ecode=",USIMERR,"
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=$zdirectory
	quit
env	; GET /test/env Test X-YDB-Env-Vars
	if $get(httpargs("crash"))=1 set $ecode=",USIMERR,"
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=$ztrnlnm("ydb_dir")
	quit
gce	; GET /test/gce Test X-YDB-Global-Directory with X-YDB-Working-Directory with X-YDB-Env-Vars
	if $get(httpargs("crash"))=1 set $ecode=",USIMERR,"
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=$zgbldir_"|"_$zdirectory_"|"_$ztrnlnm("ydb_dir")
	quit
	;
wsport	; GET /test/ws-port Tests --ws-port parameter
	set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
	set httprsp=httpoptions("ws-port")
	quit
	;
getbinary	; GET /test/getbinary Tests binary data
	set httprsp("mime")="application/octet-stream"
	set httprsp=$zchar(128)
	quit
	;
filesys(argpath) ; Handle reads from File system.
	; Ensure Directory has a trailing slash
	; Otherwise a directory like $ydb_dist/plugin/etc/ydbgui is not readable
	if httpoptions("directory")'="",$extract(httpoptions("directory"),$length(httpoptions("directory")))'="/" set httpoptions("directory")=httpoptions("directory")_"/"
	;
	; get the actual path
	new path set path=httpoptions("directory")_argpath
	;
	; Verify that no path traversal is being done.
	; NB1: not using "SYMLINK" arg to $ZPARSE since I think it's a valid case have to
	; have paths symlinked by the user under the web root directory
	; NB2: Aware of the possibility of users using Unicode and URL-Encoded
	; paths. They are in the test tPathTraversal. They are not handled because:
	;      1. YottaDB does not decode Unicode paths
	;      2. We do not url decode paths, only arguments; any url encoded
	;         paths will be passed as is and won't be traversed
	new rootpath set rootpath=$zparse(httpoptions("directory"))
	new reqfile   set reqfile=$zparse(path)
	do:httplog>2 stdout^%ydbwebutils("rootpath: "_rootpath)
	do:httplog>2 stdout^%ydbwebutils("requested file: "_reqfile)
	if reqfile="" do setError^%ydbwebutils("404","File not found") quit
	if rootpath'=$zextract(reqfile,1,$length(rootpath)) do setError^%ydbwebutils("403","Path falls outside start-up directory") quit
	;
	; GT.M errors out on file not found
	new $etrap set $etrap="goto filesyse"
	;
	; Fixed prevents Reads to terminators on SD's. CHSET makes sure we don't analyze UTF.
	open path:(rewind:readonly:fixed:chset="M")
	;
	; Get mime type
	; This isn't complete, by any means; it just grabs the most likely types to be
	; found on an M Web Server. A few common Microsoft types are supported, but
	; few other vendor-specific types are. Also, there are a few Mumps-centric
	; types added below (under the x- prefix). If it's an unrecognized file
	; extension, it's set to text.
	new mime
	set mime("aif")="audio/aiff"
	set mime("aiff")="audio/aiff"
	set mime("au")="audio/basic"
	set mime("avi")="video/avi"
	set mime("css")="text/css; charset=utf-8"
	set mime("csv")="text/csv; charset=utf-8"
	set mime("doc")="application/msword"
	set mime("gif")="image/gif"
	set mime("htm")="text/html; charset=utf-8"
	set mime("html")="text/html; charset=utf-8"
	set mime("ico")="image/x-icon"
	set mime("jpe")="image/jpeg"
	set mime("jpeg")="image/jpeg"
	set mime("jpg")="image/jpeg"
	set mime("js")="application/javascript"
	set mime("kid")="text/x-mumps-kid; charset=utf-8"
	set mime("m")="text/x-mumps; charset=utf-8"
	set mime("mov")="video/quicktime"
	set mime("mp3")="audio/mpeg3"
	set mime("pdf")="application/pdf"
	set mime("png")="image/png"
	set mime("ppt")="application/vnd.ms-powerpoint"
	set mime("ps")="application/postscript"
	set mime("qt")="video/quicktime"
	set mime("svg")="image/svg+xml"
	set mime("tex")="application/x-tex"
	set mime("tif")="image/tiff"
	set mime("tiff")="image/tiff"
	set mime("txt")="text/plain; charset=utf-8"
	set mime("log")="text/plain; charset=utf-8"
	set mime("wav")="audio/wav"
	set mime("xls")="application/vnd.ms-excel"
	set mime("zip")="application/zip"
	set mime("woff")="font/woff"
	set mime("woff2")="font/woff2"
	set mime("ttf")="font/ttf"
	set mime("eot")="font/eot"
	set mime("otf")="font/otf"
	new ext set ext=$zpiece(path,".",$length(path,"."))
	if $data(mime(ext)) set httprsp("mime")=mime(ext)
	else  set httprsp("mime")=mime("txt")
	;
	; Read operation
	use path
	new c set c=1
	new x for  read x#4079:0 set httprsp(c)=x,c=c+1 quit:$zeof
	close path
	;
	; Create ETag
	new etag set etag=""
	for c=0:0 set c=$order(httprsp(c)) quit:'c  set etag=$zyhash(etag_httprsp(c))
	set httprsp("ETag")=etag
	; 
	quit
	;
filesyse ; 500
	set $ecode=""
	do setError^%ydbwebutils("500",$zstatus)
	quit
	;
	; Copyright (c) 2013-2020 Sam Habiel
	; Copyright (c) 2018 Kenneth McGlothlen
	; Copyright (c) 2022-2025 YottaDB LLC
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
