%ydbwebreq ;SLC/KCM -- Listen for HTTP requests;Jun 20, 2022@14:46
 ;
 ; Listener Process ---------------------------------------
 ;
go ; start up REST listener with defaults
 D job(9080)
 QUIT
 ;
job(PORT,TLSCONFIG,HTTPLOG,USERPASS,NOGZIP) ; Convenience entry point
 I $L($G(USERPASS))&($G(USERPASS)'[":") W "USERPASS argument is invalid, must be in username:password format!" QUIT
 J start^%ydbwebreq(PORT,,$G(TLSCONFIG),$G(HTTPLOG),,$G(USERPASS),$G(NOGZIP)):(IN="/dev/null":OUT="/dev/null":ERR="/dev/null"):5  ; no in and out files please.
 QUIT
 ;
start(TCPPORT,DEBUG,TLSCONFIG,HTTPLOG,USERPASS,NOGZIP) ; set up listening for connections
 ; I hope TCPPORT needs no explanations.
 ;
 ; DEBUG is so that we run our server in the foreground.
 ; You can place breakpoints at CHILD+1 or anywhere else.
 ;
 ; Enable CTRL-C
 U $p:(ctrap=$char(3):exception="use $p write ""Caught Ctrl-C, stopping..."",! HALT")
 ;
 ; Initialize the variables
 S TCPPORT=$G(TCPPORT,9080)
 S DEBUG=$G(DEBUG,0)
 S TLSCONFIG=$G(TLSCONFIG)
 S HTTPLOG=$G(HTTPLOG,1)
 S USERPASS=$G(USERPASS)
 S NOGZIP=$G(NOGZIP,0)
 ;
 WRITE "Starting Server at port "_TCPPORT," "
 WRITE:TLSCONFIG'="" "using TLS configuration "_TLSCONFIG
 WRITE !
 ;
 ; Device ID
 S TCPIO="SCK$"_TCPPORT
 ;
 ; Open Code
 O TCPIO:(LISTEN=TCPPORT_":TCP":delim=$C(13,10):attach="server"):15:"socket" E  U 0 W !,"error cannot open port "_TCPPORT Q
 ;
 U TCPIO:(CHSET="M")
 ;
 W /LISTEN(5) ; Listen 5 deep - sets $KEY to "LISTENING|socket_handle|portnumber"
 N PARSTDOUT S PARSTDOUT="/proc/"_$JOB_"/fd/1" ; STDOUT for the parent process (to use for logging to STDOUT)
 N PPID S PPID=$JOB ; Parent PID for the child process
 N PARSOCK S PARSOCK=$P($KEY,"|",2)  ; Parent socket
 N CHILDSOCK  ; That will be set below; Child socket
 ;
 I DEBUG D DEBUG(TLSCONFIG)
 ;
LOOP ; wait for connection, spawn process to handle it. GOTO favorite.
 ; ----- GT.M CODE ----
 ; In GT.M $KEY is "CONNECT|socket_handle|portnumber" then "READ|socket_handle|portnumber"
 ;
 ; Wait until we have a connection (inifinte wait). 
 ; Stop if the listener asked us to stop.
 FOR  W /WAIT(10) Q:$KEY]""
 ;
 ; At connection, job off the new child socket to be served away.
 I $P($KEY,"|")="CONNECT" D  ; >=6.1
 . S CHILDSOCK=$P($KEY,"|",2)
 . U TCPIO:(detach=CHILDSOCK)
 . N Q S Q=""""
 . N ARG S ARG=Q_"SOCKET:"_CHILDSOCK_Q
 . N TCPIO ; Don't pass this guy down
 . N J S J="CHILD:(input="_ARG_":output="_ARG_":error=""/dev/null"":pass:cmd=""CHILD^%ydbwebreq -p "_PPID_""")"
 . J @J
 G LOOP
 QUIT
 ;
DEBUG(TLSCONFIG) ; Debug continuation. We don't job off the request, rather run it now.
 ; Stop using Ctrl-C (duh!)
 N $ET S $ET="BREAK"
 U $I:(CENABLE:ioerror="T")
 F  W /WAIT(10) I $KEY]"" G CHILD
 QUIT
 ; Child Handling Process ---------------------------------
 ;
 ; The following variables exist during the course of the request
 ; HTTPREQ contains the HTTP request, with subscripts as follow --
 ; HTTPREQ("method") contains GET, POST, PUT, HEAD, or DELETE
 ; HTTPREQ("path") contains the path of the request (part from server to ?)
 ; HTTPREQ("query") contains any query params (part after ?)
 ; HTTPREQ("header",name) contains a node for each header value
 ; HTTPREQ("body",n) contains as an array the body of the request
 ; HTTPREQ("location") stashes the location value for PUT, POST
 ; HTTPREQ("store") stashes the type of store (vpr or data)
 ;
 ; HTTPRSP contains the HTTP response (or name of global with the response)
 ; HTTPLOG indicates the logging level for this process
 ; HTTPERR non-zero if there is an error state
 ;
CHILD ; handle HTTP requests on this connection
 N $ET S $ET="G ETSOCK^%ydbwebreq"
 S %WTCP=$GET(TCPIO,$PRINCIPAL) ; TCP Device
 K TCPIO
 ;
 N DEVTMP ZSHOW "D":DEVTMP
 N HTTPREMOTEIP
 N I F I=0:0 S I=$O(DEVTMP("D",I)) Q:'I  I DEVTMP("D",I)["REMOTE" S HTTPREMOTEIP=$P($P(DEVTMP("D",I),"REMOTE=",2),"@")
 K DEVTMP,I
 ;
 I HTTPLOG>0 D STDOUT("Starting Child at PID "_$J_" from parent "_PPID)
 ;
TLS ; Turn on TLS?
 I TLSCONFIG]"" W /TLS("server",1,TLSCONFIG)
 ; put a break point here to debug TLS
 N D,K,T
 S D=$DEVICE,K=$KEY,T=$TEST
 I HTTPLOG>0,TLSCONFIG]"" D
 . D LOGREQ("TLS Connection Data: ")
 . D LOGREQ("            $DEVICE: "_D)
 . D LOGREQ("               $KEY: "_K)
 . D LOGREQ("              $TEST: "_T)
 I D D LOGREQ("Disconnecting due to TLS error") C %WTCP HALT
 ;
NEXT ; begin next request
 K HTTPREQ,HTTPRSP,HTTPERR
 ;
WAIT ; wait for request on this connection
 U %WTCP:(delim=$C(13,10):chset="M") ; GT.M Delimiters
 R TCPX:10
 I '$T G ETDC
 I '$L(TCPX) G ETDC
 ;
 ; -- got a request and have the first line
 I HTTPLOG>2 D LOGRAW(TCPX)
 I HTTPLOG>1 D LOGHDR(TCPX)
 I HTTPLOG>0 D LOGREQ(TCPX)
 ;
 S HTTPREQ("method")=$P(TCPX," ")
 S HTTPREQ("path")=$P($P(TCPX," ",2),"?")
 S HTTPREQ("query")=$P($P(TCPX," ",2),"?",2,999)
 ;
 I $E($P(TCPX," ",3),1,4)'="HTTP" G NEXT
 ;
 ; -- read the rest of the lines in the header
 F  S TCPX=$$RDCRLF() Q:'$L(TCPX)  D ADDHEAD(TCPX)
 ;
 ; -- Handle Contiuation Request
 I $G(HTTPREQ("header","expect"))="100-continue" D:HTTPLOG>0 LOGCN W "HTTP/1.1 100 Continue",$C(13,10,13,10),!
 ;
 ; -- decide how to read body, if any
 U %WTCP:(nodelim) ; GT.M Stream mode
 I $$LOW^%ydbwebutils($G(HTTPREQ("header","transfer-encoding")))="chunked" D
 . D RDCHNKS ; TODO: handle chunked input
 . I HTTPLOG>2 ; log array of chunks
 I $G(HTTPREQ("header","content-length"))>0 D
 . D RDLEN(HTTPREQ("header","content-length"),99)
 . I HTTPLOG>2 D LOGBODY
 ;
 ; -- build response (map path to routine & call, otherwise 404)   
 S $ETRAP="G ETCODE^%ydbwebreq"
 S HTTPERR=0
 D RESPOND^%ydbwebrsp
 S $ETRAP="G ETSOCK^%ydbwebreq"
 ;
 ; -- write out the response (error if HTTPERR>0)
 U %WTCP:(nodelim) ; GT.M Stream mode
 I $G(HTTPERR) D RSPERROR^%ydbwebrsp ; switch to error response
 I HTTPLOG>2 D LOGRSP
 D SENDATA^%ydbwebrsp
 ;
 ; -- exit on Connection: Close
 I $$LOW^%ydbwebutils($G(HTTPREQ("header","connection")))="close" C %WTCP HALT
 ;
 ; -- otherwise get ready for the next request
 G NEXT
 ;
RDCRLF() ; read a header line
 ; fixes a problem where the read would terminate before CRLF
 ; (on a packet boundary or when 1024 characters had been read)
 N X,LINE,RETRY
 S LINE=""
 F RETRY=1:1 R X:1 D:HTTPLOG>2 LOGRAW(X) S LINE=LINE_X Q:$A($ZB)=13  Q:RETRY>10
 Q LINE
 ;
RDCHNKS ; read body in chunks
 Q  ; still need to implement
 ;
RDLEN(REMAIN,TIMEOUT) ; read L bytes with timeout T
 N X,LINE,LENGTH
 S LINE=0
RDLOOP ;
 ; read until L bytes collected
 ; quit with what we have if read times out
 S LENGTH=REMAIN I LENGTH>4000 S LENGTH=4000
 R X#LENGTH:TIMEOUT
 I '$T D:HTTPLOG>2 LOGRAW("timeout:"_X) S LINE=LINE+1,HTTPREQ("body",LINE)=X Q
 I HTTPLOG>2 D LOGRAW(X)
 S REMAIN=REMAIN-$ZL(X) ; Issue 55: UTF-8 bodies
 S LINE=LINE+1,HTTPREQ("body",LINE)=X
 G:REMAIN RDLOOP
 Q
 ;
ADDHEAD(LINE) ; add header name and header value
 ; expects HTTPREQ to be defined
 D:HTTPLOG>1 LOGHDR(LINE)
 N NAME,VALUE
 S NAME=$$LOW^%ydbwebutils($$LTRIM^%ydbwebutils($P(LINE,":")))
 S VALUE=$$LTRIM^%ydbwebutils($P(LINE,":",2,99))
 I LINE'[":" S NAME="",VALUE=LINE
 I '$L(NAME) S NAME=$G(HTTPREQ("header")) ; grab the last name used
 I '$L(NAME) Q  ; no header name so just ignore this line
 I $D(HTTPREQ("header",NAME)) D
 . S HTTPREQ("header",NAME)=HTTPREQ("header",NAME)_","_VALUE
 E  D
 . S HTTPREQ("header",NAME)=VALUE,HTTPREQ("header")=NAME
 Q
 ;
ETSOCK ; error trap when handling socket (i.e., client closes connection)
 D LOGERR
 C %WTCP
 HALT  ; exit because connection has been closed
 ;
ETCODE ; error trap when calling out to routines
 S $ETRAP="G ETBAIL^%ydbwebreq"
 I $TLEVEL TROLLBACK ; abandon any transactions
 L                   ; release any locks
 i $d(%webcrash2) s $ec=",U-test-error-trap,"
 ; Set the error information and write it as the HTTP response.
 I $D(%WNULL) C %WNULL
 U %WTCP
 N ERRTXT S ERRTXT=$ZSTATUS
 N ERRARR
 S ERRARR("message")=ERRTXT
 S ERRARR("reason")=$ECODE
 S ERRARR("place")=$STACK($STACK(-1),"PLACE")
 S ERRARR("mcode")=$STACK($STACK(-1),"MCODE")
 D SETERROR^%ydbwebutils(501,,.ERRARR) ; sets HTTPERR
 D LOGERR
 D RSPERROR^%ydbwebrsp  ; switch to error response
 D SENDATA^%ydbwebrsp
 ; This next line will 'unwind' the stack and got back to listening
 ; for the next HTTP request (goto NEXT).
 S $ETRAP="Q:$ESTACK&$QUIT 0 Q:$ESTACK  S $ECODE="""" G NEXT",$ECODE=",U-UNWIND,"
 Q
ETDC ; error trap for client disconnect ; not a true M trap
 D:HTTPLOG>0 LOGDC
 C $P  
 HALT ; Stop process 
 ;
ETBAIL ; error trap of error traps
 U %WTCP
 W "HTTP/1.1 500 Internal Server Error",$C(13,10),$C(13,10),!
 C %WTCP
 HALT  ; exit because we can't recover
 ;
LOGREQ(X) ; log first Request line
 D STDOUT(X)
 QUIT
 ;
LOGRAW(X) ; log raw lines read in
 D STDOUT("Raw: "_X_" $ZB: "_$A($ZB))
 QUIT
 ;
LOGHDR(X) ; log header lines read in
 D STDOUT("Req header: "_X)
 QUIT
 ;
LOGBODY ; log the request body
 I '$D(HTTPREQ("body")) D STDOUT("Req Body: none") QUIT
 N I F I=0:0 S I=$O(HTTPREQ("body",I)) Q:'I  D STDOUT("Req Body "_I_": "_HTTPREQ("body",I))
 QUIT
 ;
LOGRSP ; log the response before sending
 I '$L($G(HTTPRSP))&'$O(HTTPRSP("")) D STDOUT("No response") QUIT
 D STDOUT("Response: ")
 D STDOUTZW($NA(HTTPRSP))
 QUIT
 ;
LOGCN ; log continue
 D STDOUT("Responded to expect/continue with HTTP/1.1 100 Continue")
 QUIT
 ;
LOGDC ; log client disconnection; VEN/SMH
 D STDOUT("Disconnect/Halt "_$J)
 QUIT
 ;
LOGERR ; log error information
 N ERR
 ZSHOW "*":ERR
 D STDOUT("Error: "_$ZSTATUS)
 D STDOUTZW($NA(ERR))
 Q
 ;
STDOUT(MSG) ; [Internal] Log to STDOUT
 ; 127.0.0.1 - - [02/Sep/2022 11:03:33] "GET / HTTP/1.1" 200 -
 N OLDIO S OLDIO=$IO
 O PARSTDOUT U PARSTDOUT
 W HTTPREMOTEIP," - - [",$ZDATE($H,"DD/MON/YYYY 12:60:SS AM"),"] "
 W MSG,!
 U OLDIO C PARSTDOUT
 QUIT
 ;
STDOUTZW(V)
 N OLDIO S OLDIO=$IO
 O PARSTDOUT U PARSTDOUT
 ZWRITE @V
 U OLDIO C PARSTDOUT
 QUIT
 ;
stop(options) ; tell the listener to stop running
	if '$data(options)#2 do cmdline(.options)
	if '$data(options("port")) set options("port")=9080
	new serverProcess set serverProcess=$$portIsOpen(options("port"),$get(options("tls")),$get(options("tlsconfig")))
	if serverProcess do
	. write "Now going to stop it...",!
	. open "mupip":(shell="/bin/sh":command="$ydb_dist/mupip stop "_serverProcess)::"pipe"
	. use "mupip"
	. new output read output
	. use $principal close "mupip"
	. write output,!
	quit
	;
portIsOpen(port,tls,tlsconfig) ; [$$ Private] Check if port is open, if so, return server process
	open "porttest":(connect="127.0.0.1:"_port_":TCP":delim=$char(13,10):attach="client"):0:"SOCKET"
	new serverpid set serverpid=0
	new error set error=0
	if $test do  quit serverpid
	. write "Port "_options("port")_" is currently being used.",!
	. write "Checking if it is the YDB-Web-Server.",!
	. ;
	. use "porttest"
	. ; TLS config
	. if $get(options("tls")) new d do
	.. if $get(options("tlsconfig"))'="" write /tls("client",,options("tlsconfig"))
	.. else  write /tls("client")
	.. set d=$device
	.. use $principal write "Using TLS. $DEVICE: "_d,!
	.. if d write "TLS error, exiting...",! close "porttest" set error=1 quit
	.. use "porttest"
	. quit:error
	. write "GET /ping HTTP/1.1"_$char(13,10)
	. write "Host: localhost:"_options("port")_$char(13,10)
	. write "User-Agent: "_$zposition_$char(13,10)
	. write "Accept: */*"_$char(13,10)_$char(13,10)
	. new httpstatus read httpstatus
	. use $principal
	. write httpstatus,!
	. use "porttest"
	. new body
	. do  close "porttest"
	. . if httpstatus'["200 OK" use $principal write "Not a YDB Web Server",! set error=1 quit
	. . new i for i=1:1 read header(i) quit:header(i)=""  set headerByType($piece(header(i),": "))=$piece(header(i),": ",2,99)
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
	;
cmdline(options) ; [Private] Process command line options
	; Input: .options("port") server port
	new cmdline set cmdline=$zcmdline
	if cmdline="" quit
	do trimleadingstr^%XCMD(.cmdline," ")
	if cmdline="" quit
	for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do ; process options
	. if $$trimleadingstr^%XCMD(.cmdline,"port") do  quit
	.. set options("port")=$$trimleadingdelimstr^%XCMD(.cmdline)
	.. do trimleadingstr^%XCMD(.cmdline," ")
	. ;
	. if $$trimleadingstr^%XCMD(.cmdline,"tls") do  quit
	.. set options("tls")=1
	.. do trimleadingstr^%XCMD(.cmdline," ")
	.. if $extract(cmdline)="-" quit
	.. set options("tlsconfig")=$$trimleadingpiece^%XCMD(.cmdline)
	.. do trimleadingstr^%XCMD(.cmdline," ")
	quit
	;
 ;
 ; Portions of this code are public domain, but it was extensively modified
 ; Copyright (c) 2013-2019 Sam Habiel
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
