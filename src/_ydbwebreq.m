%ydbwebreq ;SLC/KCM -- Listen for HTTP requests;Jun 20, 2022@14:46
	;
	; Listener Process ---------------------------------------
	;
	goto start2
	;
start(httpoptions) ; set up listening for connections
start2 ; From the top
	; Initial trap for parent process
	set $etrap="use 0 write $zstatus,! zhalt 1"
	;
	; Enable CTRL-C
	use $principal:(ctrap=$zchar(3):exception="use $principal write ""Caught Ctrl-C, stopping..."",! do shutdown^%ydbwebreq($j) halt")
	;
	; == Parse Options and Set Default Values
	do cmdline(.httpoptions)
	;
	if '$data(httpoptions("port"))          set httpoptions("port")=9080                    ; --port nnnn
	;
	; You can place breakpoints at child+1 or anywhere else.
	;
	; General Options
	; --debug is so that we run our server in the foreground.
	if '$data(httpoptions("debug"))         set httpoptions("debug")=""                     ; --debug
	if '$data(httpoptions("tlsconfig"))     set httpoptions("tlsconfig")=""                 ; --tlsconfig myconfig
	if '$data(httpoptions("log"))           set httpoptions("log")=0                        ; --log n
	if '$data(httpoptions("gzip"))          set httpoptions("gzip")=0                       ; --gzip
	if '$data(httpoptions("readwrite"))     set httpoptions("readwrite")=0                  ; --readwrite
	if '$data(httpoptions("directory"))     set httpoptions("directory")=$zdirectory        ; --directory /x/y/z
	;
	; YDBGUI options
	if '$data(httpoptions("ws-port"))       set httpoptions("ws-port")=0			; --ws-port nnnnn
	if '$data(httpoptions("client-config")) set httpoptions("client-config")=""             ; --client-config /x/y/z
	if '$data(httpoptions("allow-env-mod")) set httpoptions("allow-env-mod")=""             ; --allow-env-mod
	;
	; Authentication/Authorization Options
	if '$data(httpoptions("auth-stdin"))    set httpoptions("auth-stdin")=0                 ; --auth-stdin
	if '$data(httpoptions("auth-file"))     set httpoptions("auth-file")=""                 ; --auth-file
	if '$data(httpoptions("token-timeout")) set httpoptions("token-timeout")=15*60          ; --token-timeout in seconds (default: 15 minutes)
	; == END Option Parse
	;
	; == Initialize the global variables
	set httplog=httpoptions("log")
	set httpreadwrite=httpoptions("readwrite")
	set httpremoteip="<PARENT>" ; This is overwritten once we get a connection
	;
	new parentStdout set parentStdout="/proc/"_$job_"/fd/1" ; STDOUT for the parent process (to use for logging to STDOUT)
	new parentStdoutAvailable set parentStdoutAvailable=$$stdoutavail^%ydbwebutils(parentStdout) ; Is it available? (boolean)
	if httplog>3 do sstep^%ydbwebutils ; --log 4 will print each line as it's executed
	; 
	; Set-up Authentication global variables
	if (httpoptions("auth-stdin"))!(httpoptions("auth-file")'="") set httphasusers=1
	else  set httphasusers=0
	;
	new libsodiumFound set libsodiumFound=0
	if httphasusers do
	. if $zsearch("$ydb_dist/plugin/libsodium.so")="" quit
	. new xcpath set xcpath=$zsearch("$ydb_dist/plugin/sodium.xc")
	. if xcpath="" quit
	. set libsodiumFound=1
	. if $ztrnlnm("ydb_xc_sodium")="" view "setenv":"ydb_xc_sodium":xcpath
	if httphasusers,'libsodiumFound write "Start-up with users requested, but $ydb_dist/plugin/libsodium.so or sodium.xc not found",! zhalt 99
	;
	if httphasusers set httpwebgld=$$createTempDB^%ydbwebusers($job)
	set httpttimeout=httpoptions("token-timeout")*1000*1000 ; in microseconds for use with $zut
	; == END set-up global variables
	;
	new error set error=0
	if httpoptions("auth-stdin")        do stdin^%ydbwebusers
	if httpoptions("auth-file")'=""     set error=$$file^%ydbwebusers(httpoptions("auth-file"))
	if error write "Failed to intialize users",! zhalt 99
	kill error
	;
	;
	write "Starting Server at port "_httpoptions("port")," in directory "_httpoptions("directory")_" "
	write:httpoptions("tlsconfig")'="" "using TLS configuration "_httpoptions("tlsconfig")_" "
	write "at logging level "_httplog_" "
	write:$zlength(httpoptions("debug")) "in debug mode stopping at "_httpoptions("debug")
	write:httphasusers "using authentication "
	write:httpoptions("gzip") "enabling gzip "
	write:httpreadwrite "in readwrite mode "
	write:httpoptions("ws-port") "using port "_httpoptions("ws-port")_" for web sockets "
	write:$zlength(httpoptions("client-config")) "with client-config "_httpoptions("client-config")_" "
	write !
	if httpoptions("allow-env-mod") do
	. write "NOTICE: You have specified that clients should be able to modify their",!
	. write "environment. This feature is normally used in development environments. If you",!
	. write "are using it in a production environment, make sure you have additional security",! 
	. write "appropriate to your use case.",!
	. write:'httphasusers "NO USERS ARE SET UP.",!
	if httplog,'parentStdoutAvailable write "Logging will be disabled as "_parentStdout_" is not writable",!
	;
	; Device ID
	set tcpio="SCK$"_httpoptions("port")
	;
	; Open Code
	open tcpio:(listen=httpoptions("port")_":TCP":delim=$zchar(13,10):attach="server"):0:"socket" E  use 0 write "Error: Cannot open port "_httpoptions("port"),! quit
	;
	use tcpio:(chset="M")
	;
	write /listen(5) ; Listen 5 deep - sets $KEY to "LISTENING|socket_handle|portnumber"
	set httpparentpid=$job ; Parent PID for the child process
	new childsock  ; That will be set below; Child socket
	;
	if $zlength(httpoptions("debug")) zbreak @httpoptions("debug") do debug
	;
	; Token clean-up set-up
	new cleanupTimeSchedule
	set cleanupTimeSchedule=$zut
	;
	; Job command error file (create copy in case we need to delete it right away before job command creates it)
	new jobCommandErrorFile set jobCommandErrorFile=$$jobCommandErrorFile()
	open jobCommandErrorFile:newversion
	close jobCommandErrorFile
	;
loop ; wait for connection, spawn process to handle it. GOTO favorite.
	;
	; ----- YottaDB CODE ----
	; In YottaDB $KEY is "CONNECT|socket_handle|portnumber" then "READ|socket_handle|portnumber"
	;
	; Wait until we have a connection (infinite wait).
	for  write /wait(10) quit:$key]""  do:(httphasusers&(httplog>2)) debugtokens
	;
	; httpttimeout could be zero (no timeout), so we need to check it's positively valued
	if httphasusers,httpttimeout,($zut-cleanupTimeSchedule)>httpttimeout set cleanupTimeSchedule=$zut do tokencleanup
	;
	; At connection, job off the new child socket to be served away.
	if $zpiece($key,"|")="CONNECT" do  ; >=6.1
	. set childsock=$zpiece($key,"|",2)
	. use tcpio:(detach=childsock)
	. new q set q=""""
	. new arg set arg=q_"SOCKET:"_childsock_q
	. new tcpio ; Don't pass this guy down
	. new $etrap,$estack set $etrap="goto jobError^"_$text(+0)
	. new j set j="child:(input="_arg_":output="_arg_":error="_q_jobCommandErrorFile_q_":pass:cmd=""child^%ydbwebreq -p "_httpparentpid_""")"
	. job @j
	goto loop
	quit
	;
jobError ; $etrap for Job errors
	;set $zstep="new oio s oio=$io u 0 zp @$zpos b  u oio"
	;break
	set $etrap="use 0 write $zstatus,! zhalt 1"
	new ecode,status
	set ecode=$ecode
	set status=$zstatus
	set $ecode="",$zstatus=""
	if ecode[",Z150373114," do  ; fork failure command
	. new oldio set oldio=$io
	. use $principal write "Job fork error:"_status,!
	. open jobCommandErrorFile use jobCommandErrorFile
	. new x read x
	. close jobCommandErrorFile
	. write "Job error file contents: "_x,!
	. use oldio:(attach=childsock)
	. close oldio:(SOCKET=childsock)
	. use oldio
	. hang .1
	else  do  ; other fatal error
	. use $principal
	. write status,!
	. zhalt 1
	; This next line will 'unwind' the stack and go back to listening
	set $etrap="quit:$estack&$quit 0 quit:$estack  set $ecode=""""",$ecode=",U-unwind,"
	quit
	;
tokencleanup ; Clean-up old tokens
	if httplog>1 do stdout^%ydbwebutils("Cleaning Tokens")
	do tokenCleanup^%ydbwebusers
	quit
	;
debugtokens
	new $zgbldir set $zgbldir=httpwebgld
	do stdout^%ydbwebutils("Users")
	do:$data(^users) stdoutzw^%ydbwebutils("^users")
	do stdout^%ydbwebutils("Tokens")
	do:$data(^tokens) stdoutzw^%ydbwebutils("^tokens")
	do:$data(^tokensByTime) stdoutzw^%ydbwebutils("^tokensByTime")
	quit
	;
debug ; Debug continuation. We don't job off the request, rather run it now.
	; Stop using Ctrl-C
	new $etrap set $etrap="break"
	use $io:(cenable:ioerror="T")
	for  write /wait(10) if $key]"" goto child
	quit
	; Child Handling Process ---------------------------------
	;
	; The following variables exist during the course of the request
	; httpreq contains the HTTP request, with subscripts as follow --
	; httpreq("method") contains GET, POST, PUT, HEAD, or DELETE
	; httpreq("path") contains the path of the request (part from server to ?)
	; httpreq("query") contains any query params (part after ?)
	; httpreq("header",name) contains a node for each header value
	; httpreq("body",n) contains as an array the body of the request
	; httpreq("location") stashes the location value for PUT, POST
	;
	; httprsp contains the HTTP response (or name of global with the response)
	; httplog indicates the logging level for this process
	; httperr non-zero if there is an error state
	;
child ; handle HTTP requests on this connection
	set %ydbtcp=$get(tcpio,$principal) ; TCP Device
	kill tcpio
	if httplog>3 do sstep^%ydbwebutils ; experimental ... some bugs still in it.
	new $etrap set $etrap="goto etsock^%ydbwebreq"
	;
	new devtmp zshow "d":devtmp
	new i for i=0:0 set i=$order(devtmp("D",i)) quit:'i  if devtmp("D",i)["REMOTE" set httpremoteip=$zpiece($zpiece(devtmp("D",i),"REMOTE=",2),"@")
	kill devtmp,i
	;
	if httplog>0 do stdout^%ydbwebutils("Starting Child at PID "_$J_" from parent "_httpparentpid)
	;
tls ; Turn on TLS?
	if httpoptions("tlsconfig")]"" write /tls("server",1,httpoptions("tlsconfig"))
	; put a break point here to debug TLS
	new d,k,t
	set d=$device,k=$key,t=$test
	if httplog>0,httpoptions("tlsconfig")]"" do
	. do logreq("TLS Connection Data: ")
	. do logreq("            $DEVICE: "_d)
	. do logreq("               $KEY: "_k)
	. do logreq("              $TEST: "_t)
	if d do logreq("Disconnecting due to TLS error") close %ydbtcp halt
	;
next ; begin next request
	kill httpreq,httprsp,httperr
	use %ydbtcp:(delim=$zchar(13,10):chset="M") ; GT.M Delimiters
	read tcpx:1
	if '$test goto etdc
	if '$zlength(tcpx) goto etdc
	;
	; -- got a request and have the first line
	if httplog>2 do lograw(tcpx) ; 3 and higher print everything
	if httplog>1 do loghdr(tcpx) ; 2 and higher print logs
	if httplog>0 do logreq(tcpx) ; 1 and higher print requests
	;
	set httpreq("method")=$zpiece(tcpx," ")
	set httpreq("path")=$zpiece($zpiece(tcpx," ",2),"?")
	set httpreq("query")=$zpiece($zpiece(tcpx," ",2),"?",2,999)
	;
	if $zextract($zpiece(tcpx," ",3),1,4)'="HTTP" goto next
	;
	; -- read the rest of the lines in the header
	for  set tcpx=$$rdcrlf() quit:'$zlength(tcpx)  do addhead(tcpx)
	;
	; -- Handle Contiuation Request
	if $get(httpreq("header","expect"))="100-continue" do:httplog>0 logcn write "HTTP/1.1 100 Continue"_$zchar(13,10,13,10)
	;
	; -- decide how to read body, if any
	if $zconvert($get(httpreq("header","transfer-encoding")),"l")="chunked" D
	. ; -- See if we need to process each chunk separately
	. new routine,args,authneeded,chunkcallback
	. do matchr^%ydbwebrsp(.routine,.args,.authneeded,.chunkcallback)
	. do rdchnks
	if $get(httpreq("header","content-length"))>0 D
	. use %ydbtcp:(nodelim) ; GT.M Stream mode
	. do rdlen(httpreq("header","content-length"),99,0)
	. i httplog>2 do logbody
	;
	; -- build response (map path to routine & call, otherwise 404)   
	set $etrap="goto etcode^%ydbwebreq"
	set httperr=0
	do respond^%ydbwebrsp
	set $etrap="goto etsock^%ydbwebreq"
	;
	; -- write out the response (error if httperr>0)
	use %ydbtcp:(nodelim) ; GT.M Stream mode
	if $get(httperr) do rsperror^%ydbwebrsp ; switch to error response
	if httplog>2 do logrsp
	do sendata^%ydbwebrsp
	;
	; -- exit on Connection: Close
	if $zconvert($get(httpreq("header","connection")),"l")="close" close %ydbtcp HALT
	;
	; -- otherwise get ready for the next request
	goto next
	;
rdcrlf() ; read a header line
	; fixes a problem where the read would terminate before CRLF
	; (on a packet boundary or when 1024 characters had been read)
	new x,line,retry
	set line=""
	for retry=1:1 read x:1 do:httplog>2 lograw(x) set line=line_x quit:$zascii($zb)=13  quit:retry>10
	quit line
	;
rdchnks ; read body in chunks
	new hexlen,declen,crlf,done,line
	if httplog>1 do stdout^%ydbwebutils("*** Reading chunks... ***")
	set (done,line)=0
	for  do  quit:done
	. set hexlen=$$rdcrlf()
	. set declen=$$hex2dec^%ydbwebutils($zconvert(hexlen,"U"))
	. if declen=0 set crlf=$$rdcrlf() set done=1 quit
	. if httplog>1 do stdout^%ydbwebutils("Will read "_declen)
	. use %ydbtcp:(nodelim) ; GT.M Stream mode
	. do rdlen(declen,99,.line)
	. use %ydbtcp:(delim=$zchar(13,10):chset="M") ; GT.M Delimiters
	. set crlf=$$rdcrlf()
	. if chunkcallback'="" do
	.. if httplog>2 do stdout^%ydbwebutils("Running chunk callback "_chunkcallback)
	.. do @chunkcallback
	.. set line=0
	.. kill httpreq("body")
	quit
	;
rdlen(remain,timeout,line) ; read L bytes with timeout T
	new x,length
rdloop ;
	; read until L bytes collected
	; quit with what we have if read times out
	set length=remain if length>4000 set length=4000
	read x#length:timeout
	if '$test do:httplog>2 lograw("timeout:"_x) set line=line+1,httpreq("body",line)=x quit
	if httplog>2 do lograw(x)
	set remain=remain-$zlength(x) ; Issue 55: UTF-8 bodies
	set line=line+1,httpreq("body",line)=x
	goto:remain rdloop
	quit
	;
addhead(line) ; add header name and header value
	; expects httpreq to be defined
	do:httplog>1 loghdr(line)
	new name,value
	set name=$zconvert($$L^%TRIM($zpiece(line,":")),"l")
	set value=$$L^%TRIM($zpiece(line,":",2,99))
	if line'[":" set name="",value=line
	if '$zlength(name) set name=$get(httpreq("header")) ; grab the last name used
	if '$zlength(name) quit  ; no header name so just ignore this line
	if $data(httpreq("header",name)) do
	. set httpreq("header",name)=httpreq("header",name)_","_value
	else  do
	. set httpreq("header",name)=value,httpreq("header")=name
	quit
	;
etsock ; error trap when handling socket (i.e., client closes connection)
	do logerr
	close %ydbtcp
	halt  ; exit because connection has been closed
	;
etcode ; error trap when calling out to routines
	set $etrap="goto etbail^%ydbwebreq"
	if $tlevel trollback ; abandon any transactions
	lock                ; release any locks
	i $data(%webcrash2) s $ec=",U-test-error-trap,"
	if $data(%ydbnull) close %ydbnull
	; Restore original global direcotry
	if $data(httpoldgbldir) view "setenv":"ydb_gbldir":httpoldgbldir
	; Set the error information and write it as the HTTP response.
	use %ydbtcp:(nodelim) ; GT.M Stream mode
	new errtxt set errtxt=$zstatus
	new errarr
	set errarr("message")=errtxt
	set errarr("reason")=$ecode
	set errarr("place")=$stack($stack(-1),"place")
	set errarr("mcode")=$stack($stack(-1),"mcode")
	do setError^%ydbwebutils(501,"M Execution Error",.errarr) ; sets httperr
	do logerr
	do rsperror^%ydbwebrsp  ; switch to error response
	do sendata^%ydbwebrsp
	; This next line will 'unwind' the stack and got back to listening
	; for the next HTTP request (goto next).
	set $etrap="quit:$estack&$quit 0 quit:$estack  set $ecode="""" goto next",$ecode=",U-unwind,"
	quit
	;
etdc ; error trap for client disconnect ; not a true M trap
	do:httplog>0 logdc
	halt ; Stop process 
	;
etbail ; error trap of error traps
	use %ydbtcp:(nodelim) ; GT.M Stream mode
	write "HTTP/1.1 500 Internal Server Error",$zchar(13,10),$zchar(13,10),!
	close %ydbtcp
	halt  ; exit because we can't recover
	;
logreq(x) ; log first Request line
	do stdout^%ydbwebutils(x)
	quit
	;
lograw(x) ; log raw lines read in
	do stdout^%ydbwebutils("Raw: "_x_" $zb: "_$zascii($zb))
	quit
	;
loghdr(x) ; log header lines read in
	do stdout^%ydbwebutils("Req header: "_x)
	quit
	;
logbody ; log the request body
	if '$data(httpreq("body")) do stdout^%ydbwebutils("Req Body: none") quit
	new i for i=0:0 set i=$order(httpreq("body",i)) quit:'i  do stdout^%ydbwebutils("Req Body "_i_": "_httpreq("body",i))
	quit
	;
logrsp ; log the response before sending
	if '$data(httprsp) do stdout^%ydbwebutils("No response") quit
	do stdout^%ydbwebutils("Response: ")
	do stdoutzw^%ydbwebutils($name(httprsp))
	quit
	;
logcn ; log continue
	do stdout^%ydbwebutils("Responded to expect/continue with HTTP/1.1 100 Continue")
	quit
	;
logdc ; log client disconnection; VEN/SMH
	do stdout^%ydbwebutils("Disconnect/Halt "_$J)
	quit
	;
logerr ; log error information
	new err
	zshow "*":err
	do stdout^%ydbwebutils("Error: "_$zstatus)
	do stdoutzw^%ydbwebutils($name(err))
	quit
	;
stop(httpoptions) ; tell the listener to stop running
	do cmdline(.httpoptions)
	if '$data(httpoptions("port")) set httpoptions("port")=9080
	new serverProcess set serverProcess=$$portIsOpen(httpoptions("port"),$get(httpoptions("tlsconfig")))
	if serverProcess do
	. write "Now going to stop it...",!
	. open "mupip":(shell="/bin/sh":command="$ydb_dist/mupip stop "_serverProcess)::"pipe"
	. use "mupip"
	. new output read output
	. use $principal close "mupip"
	. write output,!
	. do shutdown(serverProcess)
	quit
	;
shutdown(job,silent) ; [Private] Cleanup Shutdown
	do deletedb^%ydbwebusers(job,$get(silent))
	new jobCommandErrorFile set jobCommandErrorFile=$$jobCommandErrorFile()
	open jobCommandErrorFile 
	close jobCommandErrorFile:delete
	quit
	;
portIsOpen(port,tlsconfig) ; [$$ Private] Check if port is open, if so, return server process
	open "porttest":(connect="127.0.0.1:"_port_":TCP":delim=$zchar(13,10):attach="client"):0:"SOCKET"
	new serverpid set serverpid=0
	new error set error=0
	if $test do  quit serverpid
	. write "Port "_httpoptions("port")_" is currently being used.",!
	. write "Checking if it is the YDB-Web-Server.",!
	. ;
	. use "porttest"
	. ; TLS config
	. if $get(httpoptions("tlsconfig"))'="" new d do
	.. write /tls("client",,httpoptions("tlsconfig"))
	.. set d=$device
	.. use $principal write "Using TLS. $DEVICE: "_d,!
	.. if d write "TLS error, exiting...",! close "porttest" set error=1 quit
	.. use "porttest"
	. quit:error
	. write "GET /api/ping HTTP/1.1"_$zchar(13,10)
	. write "Host: localhost:"_httpoptions("port")_$zchar(13,10)
	. write "User-Agent: "_$zposition_$zchar(13,10)
	. write "Accept: */*"_$zchar(13,10)_$zchar(13,10)
	. new httpstatus read httpstatus
	. use $principal
	. write httpstatus,!
	. use "porttest"
	. new body
	. do  close "porttest"
	. . if httpstatus'["200 OK" use $principal write "Not a YDB Web Server",! set error=1 quit
	. . new i for i=1:1 read header(i) quit:header(i)=""  set headerByType($zpiece(header(i),": "))=$zpiece(header(i),": ",2,99)
	. . if '$data(headerByType("Content-Length")) use $principal write "No Content-Length header",! set error=1 quit
	. . read body#headerByType("Content-Length"):0
	. quit:error
	. use $principal
	. write body,!
	. new parsedBody,error do decode^%ydbwebjson($na(body),$na(parsedBody),$na(error))
	. if $data(error) write "Error parsing Web Server response",! quit
	. set serverpid=$get(parsedBody("server"))
	. write "Server running at "_serverpid,!
	else  do  quit 0
	. write "Nothing listening on port "_port,!
	quit 0
	;
cmdline(httpoptions) ; [Private] Process command line httpoptions
	; Output: .httpoptions(subscript)=value
	new cmdline set cmdline=$zcmdline
	; Special case to work around a bug in YottaDB
	if $zextract(cmdline,1,3)="job" set $zextract(cmdline,1,3)=""
	if cmdline="" quit
	do trimleadingstr^%XCMD(.cmdline," ")
	if cmdline="" quit
	for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do ; process httpoptions
	. new o for o="port","log","tlsconfig","directory","token-timeout","auth-file","debug","ws-port","client-config" do
	.. if $$trimleadingstr^%XCMD(.cmdline,o) do  quit
	... set httpoptions(o)=$$trimleadingdelimstr^%XCMD(.cmdline)
	... do trimleadingstr^%XCMD(.cmdline," ")
	. ;
	. new o for o="gzip","readwrite","auth-stdin","allow-env-mod" do
	.. if $$trimleadingstr^%XCMD(.cmdline,o) set httpoptions(o)=1
	.. do trimleadingstr^%XCMD(.cmdline," ")
	quit
	;
jobCommandErrorFile() ; [$$ Private] Get job command error file
	; compute path and filename for log files
	new tmp set tmp=$zsearch("$ydb_tmp")
	quit $select($zlength(tmp):tmp,1:"/tmp")_"/"_$text(+0)_$job_".mje"
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright (c) 2013-2019 Sam Habiel
	; Copyright (c) 2018-2019 Christopher Edwards
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
