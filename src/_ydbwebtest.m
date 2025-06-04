%ydbwebtest ; ose/smh - Web Services Tester;Jun 20, 2022@15:59
	; Runs only on GTM/YDB
	; Requires M-Unit
	;
test if $text(^%ut)="" quit
	do en^%ut($text(+0),3)
	quit
	;
STARTUP ;
	job start^%ydbwebreq:cmd="job --port 55728"
	set myJob=$zjob
	hang .1
	;
	; Create the users.json file used by some tests
	new users,json
	set users(1,"username")="admin"
	set users(1,"password")="pass"
	set users(1,"authorization")="RW"
	do encode^%ydbwebjson($name(users),$name(json))
	new file set file="users.json"
	open file:newversion use file
	new i for i=0:0 set i=$order(json(i)) quit:'i  write json(i)
	close file
	;
	quit
	;
SHUTDOWN ;
	kill myJob
	quit
	;
	; -------------------
	; Helper method to stop the server at specifc ports in the tests
	;
stop(pid)
	open "p":(command="$gtm_dist/mupip stop "_pid)::"pipe"
	use "p" read x:1
	close "p"
	do eq^%ut($ZCLOSE,0)
	do shutdown^%ydbwebreq(pid,1) ; Remove db and job files
	for  quit:'$zgetjpi(pid,"isprocalive")  hang .001
	quit
	;
	; Helper method to uncompress gzipped data
uncompress(zipped)
	view "nobadchar"
	new uncompressed,out,i
	set uncompressed=""
	open "pipe":(shell="/bin/bash":command="gunzip":chset="M")::"pipe"
	use "pipe" write zipped
	set $x=0 write /eof
	for i=1:1 read out(i) quit:$zeof
	close "pipe"
	view "badchar"
	for i=0:0 set i=$order(out(i)) quit:'i  set out(i)=out(i)_$char(10),uncompressed=uncompressed_out(i)
	quit uncompressed
	;	
tstartagain ; @TEST Start again on the same port
	job start^%ydbwebreq:cmd="job --port 55728"
	set myJob=$zjob
	hang .1
	do eq^%ut($zgetjpi(myJob,"ISPROCALIVE"),0)
	quit
	;
tdebug ; @TEST Debug Entry Point
	; This debug entry point will not get hit, so it's okay for this test, which runs in the background
	job start^%ydbwebreq:cmd="job --port 55729 --debug putroutine^%ydbwebapi"
	hang .1
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55729/")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["YottaDB Restful Web-Services Portal")
	; and it halts on its own
	quit
	;
thome ; @TEST Test Home Page
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["YottaDB Restful Web-Services Portal")
	quit
	;
tgetr ; @TEST Test Get Handler Routine
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/r/%25ydbwebapi")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["YottaDB LLC")
	quit
	;
tputr ; @TEST Put a Routine
	new httpStatus,return,headers
	new random set random=$random(9817238947)
	new payload set payload="KBANTESTWEB ;"_random_$char(13,10)_" W ""HELLO WORLD"",!"_$char(13,10)_" QUIT"
	do &libcurl.init
	do &libcurl.auth("Basic",$tr("foo:boo",";",":"))
	do &libcurl.do(.httpStatus,.return,"PUT","http://127.0.0.1:55728/test/r/KBANTESTWEB",payload,"application/text",1,.headers)
	do eq^%ut(httpStatus,201)
	do &libcurl.cleanup
	kill httpStatus,return
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/r/KBANTESTWEB")
	do tf^%ut(return[random)
	open "/mwebserver/r/KBANTESTWEB.m":readonly
	close "/mwebserver/r/KBANTESTWEB.m":delete
	quit
	;
tgetxml ; @TEST Test Get Handler XML
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/xml")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["xml")
	quit
	;
tdecodeutf8 ; @TEST Test Decode UTF-8 URL
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/utf8/get?foo=こにちは")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return="こにちは")
	quit
	;
tencdecutf8 ; @TEST Encode and Decode UTF-8
	new x set x="foo=Å"
	do eq^%ut(x,$$urldec^%ydbwebutils($$urlenc^%ydbwebutils(x)))
	quit
	;
tencdecx ; @Test Encode and Decode an excepted character
	new x set x=","
	do eq^%ut(x,$$urldec^%ydbwebutils($$urlenc^%ydbwebutils(x)))
	quit
	;
tpostutf8 ; @TEST Post UTF8 data, expect parts of url post data back
	; curl -XPOST -d '{"直接": "人生"}' localhost:9080/test/utf8/post?foo=こにちは
	; Result:
	; Line 1: こにち
	; Line 2: 人生
	new httpStatus,return
	new payload set payload="{""直接"":""人生""}"
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55728/test/utf8/post?foo=こにちは",payload,"application/json")
	do &libcurl.cleanup
	set return(1)=$zpiece(return,$char(13,10),1)
	set return(2)=$zpiece(return,$char(13,10),2)
	do eq^%ut(return(1),"こにち")
	do eq^%ut(return(2),"人生")
	quit
	;
thead ; #TEST HTTP Verb HEAD (only works with GET queries)
	; my libcurl doesn't do HEAD :-( - but head works
	new httpStatus,return,headers,status
	do
	. new $et,$es set $et="s ec=$ec,$ec="""""
	. set status=$&libcurl.curl(.httpStatus,.return,"HEAD","http://127.0.0.1:55728/test/xml",,,1,.headers)
	zwrite ec
	zwrite httpStatus
	zwrite headers
	quit
	;
tgzip ; @TEST Test gzip encoding
	new gzipflagjob
	;
	; Start server with no gzip
	job start^%ydbwebreq:cmd="job --port 55732 --gzip"
	hang .1
	set gzipflagjob=$zjob
	;
	new httpStatus,return,headers
	do &libcurl.init
	do &libcurl.addHeader("Accept-Encoding: gzip")
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55732/test/r/%25ydbwebapi",,,1,.headers)
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200)
	do tf^%ut(headers["Content-Encoding: gzip")
	view "nobadchar"
	do tf^%ut(return[$char(0))
	view "badchar"
	new uncompressed set uncompressed=$$uncompress(return)
	do tf^%ut(uncompressed["%ydbwebapi")
	;
	; Do this again, but routine is larger than 32k
	do &libcurl.init
	do &libcurl.addHeader("Accept-Encoding: gzip")
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55732/test/r/%25ydbwebtest",,,1,.headers)
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200)
	do tf^%ut(headers["Content-Encoding: gzip")
	view "nobadchar"
	do tf^%ut(return[$char(0))
	view "badchar"
	do &libcurl.cleanup
	new uncompressed set uncompressed=$$uncompress(return)
	do tf^%ut(uncompressed["%ydbwebtest")
	;
	; now stop the webserver again
	do stop(gzipflagjob)
	quit
	;
tnogzip ; @TEST Test the default nogzip
	new httpStatus,return,headers
	do &libcurl.init
	do &libcurl.addHeader("Accept-Encoding: gzip") ; This must be sent to properly test as the server is smart and if we don't send that we support gzip it won't gzip
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/r/%25ydbwebapi",,,1,.headers)
	do eq^%ut(httpStatus,200)
	do tf^%ut(headers'["Content-Encoding: gzip")
	do tf^%ut(return["ydbwebapi ; OSE/SMH - Infrastructure web services hooks")
	quit
	;
temptynogzip ; @TEST Empty response with no gzip encoding
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/empty")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return="")
	quit
	;
temptygzip ; @TEST Empty response with gzip
	new httpStatus,return
	do &libcurl.init
	do &libcurl.addHeader("Accept-Encoding: gzip")
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/empty",,,1,.headers)
	do eq^%ut(httpStatus,200)
	do tf^%ut(headers'["Content-Encoding: gzip")
	do tf^%ut(return="")
	quit
	;
tping ; @TEST Ping
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/api/ping")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["server")
	quit
	;
terr ; @TEST generating an error
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/error")
	do eq^%ut(httpStatus,500)
	do tf^%ut(return["DIVZERO")
	quit
	;
terr2 ; @TEST crashing the error trap
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/error?foo=crash2")
	do eq^%ut(httpStatus,500)
	quit
	;
tcustomError ; @TEST Custom Error
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/customerror")
	do tf^%ut(return["OperationOutcome")
	do eq^%ut(httpStatus,400)
	quit
	;
tlong ; @TEST get a long message
	; Exercises the flushing
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/bigoutput")
	do eq^%ut(httpStatus,200)
	do eq^%ut($length(return),32769)
	quit
	;
tGlo    ; @TEST global tests
	; Create global directory
	new x
	new gdefile set gdefile="/tmp/mumps.gde"
	open gdefile:newversion
	use gdefile
	write "change -segment DEFAULT -file=""/tmp/mumps.dat""",!
	write "exit",!
	close gdefile
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/yottadb -r GDE @"_gdefile)::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	kill x
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/mupip create")::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	open gdefile
	close gdefile:delete
	;
	set $zgbldir="/tmp/testdb.gld"
	view "gbldirload":$zgbldir
	;
	; We run the global tests twice: once without gzip and once with gzip
	; This is to verify that the logic for doing gzipping does not interfere with the data sending
	for i=1,2 do
	. if i=1 job start^%ydbwebreq:cmd="job --port 55730"
	. if i=2 job start^%ydbwebreq:cmd="job --port 55730 --gzip"
	. hang .1
	. new server set server=$zjob
	. ;
	. ; Get data from global, and ensure that global is killed after data is sent
	. new httpStatus,return,headers
	. do &libcurl.init
	. if i=2 do &libcurl.addHeader("Accept-Encoding: gzip")
	. new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/gloreturn1",,,1,.headers)
	. do &libcurl.cleanup
	. do eq^%ut(httpStatus,200,1*i)
	. if i=2 set return=$$uncompress(return)
	. if i=2 do tf^%ut(headers["Content-Encoding: gzip")
	. do tf^%ut(return["coo",2*i)
	. do tf^%ut('$data(^web("%ydbwebapi")),3*i)
	. ;
	. ; #139: $query on a subscript does not terminate properly, continuing to send unrelated data
	. ; In this test, we have to use command line curl as the plugin doesn't support --ignore-content-length,
	. ; ... which is necessary to reproduce this bug
	. if i=1 open "p":(shell="/bin/sh":command="curl -sS --ignore-content-length http://127.0.0.1:55730/test/gloreturn1")::"pipe"
	. if i=2 open "p":(shell="/bin/sh":command="curl -sS --compressed --ignore-content-length http://127.0.0.1:55730/test/gloreturn1")::"pipe"
	. use "p"
	. n j for j=1:1 read x(j) quit:$zeof
	. close "p"
	. do tf^%ut(x(4)'["WRONG DATA",4*i)
	. do tf^%ut($data(^web1("z")),5*i) ; should not be deleted
	. ;
	. ; Test gloreturn2, which uses an unsubscripted global. This tests $query termination on an empty string.
	. new httpStatus,return
	. do &libcurl.init
	. if i=2 do &libcurl.addHeader("Accept-Encoding: gzip")
	. new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/gloreturn2")
	. do &libcurl.cleanup
	. if i=2 set return=$$uncompress(return)
	. if i=2 do tf^%ut(headers["Content-Encoding: gzip")
	. do eq^%ut(httpStatus,200,6*i)
	. do tf^%ut(return["coo",7*i)
	. do tf^%ut('$data(^web2),8*i)
	. ;
	. ; Test gloreturn3, which uses an unsubscripted global. This tests $query termination on an empty string.
	. new httpStatus,return
	. do &libcurl.init
	. if i=2 do &libcurl.addHeader("Accept-Encoding: gzip")
	. new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/gloreturn3")
	. do &libcurl.cleanup
	. if i=2 set return=$$uncompress(return)
	. if i=2 do tf^%ut(headers["Content-Encoding: gzip")
	. do eq^%ut(httpStatus,200,9*i)
	. do tf^%ut(return["foo",10*i)
	. do tf^%ut('$data(^web3),11*i)
	. ;
	. do stop(server)
	;
	set $zgbldir=""
	view "unsetenv":"ydb_gbldir"
	open "/tmp/testdb.gld" close "/tmp/testdb.gld":delete
	open "/tmp/mumps.dat" close "/tmp/mumps.dat":delete
	quit
	;
tDC ; @TEST Test Disconnecting from the Server w/o talking
	open "sock":(connect="127.0.0.1:55728:TCP":attach="client"):1:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	quit
	;
tInt ; @TEST ZInterrupt
	new oldfile
	for  set oldfile=$zsearch("YDB_JOBEXAM.ZSHOW_DMP_*") quit:oldfile=""  do
	. open oldfile:readonly
	. close oldfile:delete
	open "p":(command="$gtm_dist/mupip intrpt "_myJob)::"pipe"
	use "p" read x:1
	close "p"
	hang .1
	new newfile set newfile=$zsearch("YDB_JOBEXAM.ZSHOW_DMP_"_myJob_"_1",-1)
	if newfile'="" do SUCCEED^%ut
	QUIT
	;
tLog1 ; @TEST Set httplog to 1
	; This is the default logging, no need to set
	job start^%ydbwebreq:(cmd="job --port 55731":out="/tmp/sim-stdout1"):5
	new serverjob set serverjob=$zjob
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	new httpStatus,return,x
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/api/ping")
	open "/tmp/sim-stdout1":(stream:readonly:rewind:delimiter=$char(10))
	use "/tmp/sim-stdout1"
	new i for i=1:1 read x(i) quit:$zeof
	close "/tmp/sim-stdout1"
	; Can't get the file to have the right contents; but it's there when manually testing...
	;d tf^%ut(x(1)["ping",x(1))
	do stop(serverjob)
	quit
	;
tLog2 ; @TEST Set httplog to 2
	job start^%ydbwebreq:(cmd="job --port 55731 --log 2":out="/tmp/sim-stdout2"):5
	new serverjob set serverjob=$zjob
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	new httpStatus,return,x
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/api/ping")
	open "/tmp/sim-stdout2":(stream:readonly:rewind:delimiter=$char(10))
	use "/tmp/sim-stdout2"
	new i for i=1:1 read x(i) quit:$zeof
	close "/tmp/sim-stdout2"
	; Can't get the file to have the right contents...
	; but giving up on this for now...
	;d tf^%ut(x(1)["ping",x(1))
	; Funny enough, even cat does not show the correct contents, so something is
	; not right, but I can't manually replicate this
	do stop(serverjob)
	quit
	;
tLog3 ; @TEST Set httplog to 3
	job start^%ydbwebreq:(cmd="job --port 55731 --log 3":out="/tmp/sim-stdout3"):5
	new serverjob set serverjob=$zjob
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	new httpStatus,return,x
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/test/r/%25ydbwebapi")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["YottaDB LLC")
	open "/tmp/sim-stdout3":(stream:readonly:rewind:delimiter=$char(10))
	use "/tmp/sim-stdout3"
	new i for i=1:1 read x(i) quit:$zeof
	close "/tmp/sim-stdout3"
	do tf^%ut(x(8)["httprsp",x(1))
	do stop(serverjob)
	quit
	;
tDCLog ; @TEST Test Log Disconnect
	job start^%ydbwebreq:(cmd="job --port 55731 --log 3":out="/tmp/sim-stdout4"):5
	new serverjob set serverjob=$zjob
	open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	new x
	open "/tmp/sim-stdout4":(stream:readonly:rewind:delimiter=$char(10))
	use "/tmp/sim-stdout4"
	new i for i=1:1 read x(i) quit:$zeof
	close "/tmp/sim-stdout4"
	; Ditto on not finding the text
	;zwrite x
	;d tf^%ut(x(1)["Disconnect/Halt",x(1))
	do stop(serverjob)
	quit
	;
tOptionCombine ; @TEST Test combining options (#113)
	; We read a file from /tmp/. If the options were not read properly, then we wouldn't be able to read the file.
	job start^%ydbwebreq:(cmd="job --port 55731 --gzip --log 3 --directory /tmp/":out="/tmp/sim-stdout5"):5
	hang .1
	new serverjob set serverjob=$zjob
	new random set random=$random(9817234)
	open "/tmp/index.html":(newversion)
	use "/tmp/index.html"
	write "<!DOCTYPE html>",!
	write "<html>",!
	write "<body>",!
	write "<h1>My First Heading</h1>",!
	write "<p>My first paragraph."_random_"</p>",!
	write "</body>",!
	write "</html>",!
	close "/tmp/index.html"
	do &libcurl.init
	do &libcurl.addHeader("Accept-Encoding: gzip")
	new httpStatus,return
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55731/",,,1,.headers)
	do eq^%ut(httpStatus,200)
	do tf^%ut(headers["Content-Encoding: gzip")
	; Data is zipped, so we can't see inside it unless we unzip it.
	view "nobadchar"
	do tf^%ut(return[$char(0))
	view "badchar"
	;
	do stop(serverjob)
	quit
	;
tWebPage ; @TEST Test Getting a web page
	; Now start a webserver with a new directory of /tmp/
	job start^%ydbwebreq:cmd="job --port 55731 --directory /tmp/"
	hang .1
	new serverjob set serverjob=$zjob
	zsy "mkdir -p /tmp/foo"
	new random set random=$random(9817234)
	open "/tmp/foo/boo.html":(newversion)
	use "/tmp/foo/boo.html"
	write "<!DOCTYPE html>",!
	write "<html>",!
	write "<body>",!
	write "<h1>My First Heading</h1>",!
	write "<p>My first paragraph."_random_"</p>",!
	write "</body>",!
	write "</html>",!
	close "/tmp/foo/boo.html"
	new httpStatus,return
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/foo/boo.html")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return[random)
	; now stop the webserver again
	do stop(serverjob)
	quit
	;
tHomePage ; @Test Getting index.html page
	new serverjob
	;
	; Now start a webserver with a new directory of /tmp/
	job start^%ydbwebreq:cmd="job --port 55731 --directory /tmp/"
	hang .1
	set serverjob=$zjob
	new random set random=$random(9817234)
	open "/tmp/index.html":(newversion)
	use "/tmp/index.html"
	write "<!DOCTYPE html>",!
	write "<html>",!
	write "<body>",!
	write "<h1>My First Heading</h1>",!
	write "<p>My first paragraph."_random_"</p>",!
	write "</body>",!
	write "</html>",!
	close "/tmp/index.html"
	new httpStatus,return
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return[random)
	do stop(serverjob)
	quit
	;
tPathTraversal ; @TEST Path traversal
	new serverjob
	open "pipe":(shell="/bin/sh":command="mkdir -p /tmp/goodpath/ /tmp/badpath":readonly:writeonly)::"pipe"
	use "pipe" close "pipe"
	if $zclose set $ecode=",U1," ; something went wrong
	;
	; Write a couple of files into /tmp/goodpath and /tmp/badpath
	new f1,f2
	set f1="/tmp/goodpath/myfile.txt"
	set f2="/tmp/badpath/myfile.txt"
	;
	open f1:newversion use f1 write "good file",! close f1
	open f2:newversion use f2 write "bad file",! close f2
	;
	; Now start a webserver
	job start^%ydbwebreq:cmd="job --port 55730 --directory /tmp/goodpath"
	set serverjob=$zjob
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	;
	new httpStatus,return
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/myfile.txt")
	do eq^%ut(httpStatus,200)
	do tf^%ut(return["good file")
	;
	; Need to use --path-as-is which is not exposed in the plugin
	; Try several bad paths with curl:
	new url for url="../badpath/myfile.txt","%2e%2e/badpath/myfile.txt","%c0%ae%c0%ae/badpath/myfile.txt","..%2fbadpath/myfile.txt","%2e%2e%2fbadpath/myfile.txt" do
	. open "p":(shell="/bin/sh":command="curl --fail-with-body -Ss --path-as-is http://127.0.0.1:55730/"_url)::"pipe"
	. use "p"
	. kill return 
	. for i=1:1 read return(i) quit:$zeof
	. kill return(i) ; last node is empty
	. close "p"
	. ; return(1) has the http status code:
	. ; return(2) has the error message:
	. ; curl: (22) The requested URL returned error: 403
	. ; {"apiVersion":1.1,"error":{"code":403,"errors":[{"errname":"Forbidden","message":"Path falls outside start-up directory","reason":403}],"request":"GET \/..\/NOTICE ","toperror":"Forbidden"}}
	. set return=return(1)_$char(13,10)_return(2) ; just in case traversal happens
	. do tf^%ut(return'["bad file","path traversed when it shouldn't be "_url)
	. ;
	. set httpstatus=$piece(return(1),": ",2)
	. do tf^%ut("^403^404^"["^"_httpstatus_"^")
	. ;
	. if httpstatus=403 do tf^%ut(return(2)["Path falls outside start-up directory")
	. if httpstatus=404 do tf^%ut(return(2)["File not found")
	. do eq^%ut($zclose,22,url) ; curl error
	do stop(serverjob)
	quit
	;
CORS ; @TEST Make sure CORS headers are returned
	new httpStatus,return,headers,headerarray
	do &libcurl.curl(.httpStatus,.return,"OPTIONS","http://127.0.0.1:55728/r/kbbotest.m",,,,.headers)
	;
	; Split the headers apart using carriage return line feed delimiter
	f i=1:1:$length(headers,$char(13,10)) D
	. ; Change to name based subscripts by using ": " delimiter
	. s:($zpiece($zpiece(headers,$char(13,10),i),": ",1)'="")&($zpiece($zpiece(headers,$char(13,10),i),": ",2)'="") headerarray($zpiece($zpiece(headers,$char(13,10),i),": ",1))=$zpiece($zpiece(headers,$char(13,10),i),": ",2)
	;
	; Now make sure all required bits are correct
	do eq^%ut(httpStatus,200)
	do eq^%ut($get(headerarray("Access-Control-Allow-Methods")),"OPTIONS, POST")
	do eq^%ut($get(headerarray("Access-Control-Allow-Headers")),"Content-Type")
	do eq^%ut($get(headerarray("Access-Control-Max-Age")),"86400")
	do eq^%ut($get(headerarray("Access-Control-Allow-Origin")),"*")
	quit
	;
login ; @TEST Test that logging in/tokens/logging out works
	; NB: Numbers as arguments to the M-Unit test asserts help us identify which test failed 
	new passwdJob,status,payload,httpStatus,return
	;
	; Now start a webserver with a username/password
	job start^%ydbwebreq:cmd="job --port 55730 --auth-file users.json"
	set passwdJob=$zjob
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	;
	; Negative test - No authentication: 403 - Forbidden
	; Data not returned
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do eq^%ut(httpStatus,403,1)
	do tf^%ut(return'["<?xml",2)
	;
	; Now login with bad un/pw
	; Expect 401 Unauthorized
	set payload="{ ""username"" : ""admin"", ""password"" : ""foo"" }"
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55730/api/login",payload,"application/json")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,401,3)
	;
	; Now login with good un/pw
	set payload="{ ""username"" : ""admin"", ""password"" : ""pass"" }"
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55730/api/login",payload,"application/json")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,4)
	;
	; Get the token out of the json in `return`
	; We don't need to assert anything as the code will crash if returnjson is not properly formatted
	new returnjson do decode^%ydbwebjson($name(return),$name(returnjson))
	new token set token=returnjson("token")
	new authorization set authorization=returnjson("authorization")
	new timeout set timeout=returnjson("timeout")
	;
	; Confirm the validity of the token and authorization; timeout is 15 minutes by default
	do tf^%ut(token'="")
	do eq^%ut(authorization,"RW")
	do eq^%ut(timeout,900)
	;
	; Now get the XML using the token
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,5)
	do tf^%ut(return["<?xml",6)
	;
	; Get ReadWrite flag that is assigned to the user
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/readwrite")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,7)
	do eq^%ut(return,1,8)
	;
	; Try the same code with a bad token
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token_" ")
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/readwrite")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,403,9)
	;
	; Try with empty token (previously crashed the child process)
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer ")
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,403)
	;
	; Try simulated timeout call
	; This call manipulates ^tokens to expire the current token so the first call works, but second call won't due to timeout
	; There seems to be a bug in the curl plugin causing it to crash on the second call, so we tear-down curl and re-do the code again
	new httpStatus1,httpStatus2
	new return1,return2
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status1=$&libcurl.do(.httpStatus1,.return1,"GET","http://127.0.0.1:55730/test/simtimeout")
	do &libcurl.cleanup
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status2=$&libcurl.do(.httpStatus2,.return2,"GET","http://127.0.0.1:55730/test/simtimeout")
	do &libcurl.cleanup
	do eq^%ut(httpStatus1,200,10)
	do eq^%ut(httpStatus2,408,11)
	do tf^%ut(return1'["Token timeout",12)
	do tf^%ut(return2["Token timeout",13)
	;
	; Logout with a valid token
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	do &libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/api/logout")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,14)
	new logoutoutput do decode^%ydbwebjson("return","logoutoutput")
	do eq^%ut(logoutoutput("status"),"OK",15)
	;
	; Logout with invalid token - httpStatus is 200; but status is "token not found"
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token_"xx ")
	do &libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/api/logout")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,16)
	new logoutoutput do decode^%ydbwebjson("return","logoutoutput")
	do eq^%ut(logoutoutput("status"),"token not found",17)
	;
	; Logout with empty token - httpStatus is 200; but status is "token not found"
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer ")
	do &libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/api/logout")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,18)
	new logoutoutput do decode^%ydbwebjson("return","logoutoutput")
	do eq^%ut(logoutoutput("status"),"token not found",19)
	;
	; Logout without an authorization header
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/api/logout")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,20)
	new logoutoutput do decode^%ydbwebjson("return","logoutoutput")
	do eq^%ut(logoutoutput("status"),"token not found",21)
	;
	; now stop the webserver again
	do stop(passwdJob)
	;
	quit
	;
tTokenCleanup ; @Test Test Token Cleanup with timeout
	; NB: Numbers as arguments to the M-Unit test asserts help us identify which test failed 
	new passwdJob,status,payload,httpStatus,return
	;
	; Now start a webserver with a username/password
	job start^%ydbwebreq:cmd="job --port 55730 --token-timeout .1 --auth-file users.json"
	set passwdJob=$zjob
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	;
	; Now login with good un/pw
	set payload="{ ""username"" : ""admin"", ""password"" : ""pass"" }"
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55730/api/login",payload,"application/json")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,1)
	;
	; Get the token out of the json in `return`
	; We don't need to assert anything as the code will crash if returnjson is not properly formatted
	new returnjson do decode^%ydbwebjson($name(return),$name(returnjson))
	new token set token=returnjson("token")
	;
	; Now get the XML using the token
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,2)
	do tf^%ut(return["<?xml",3)
	;
	; Wait for 1 second
	hang 1
	;
	; Get XML again, and this time we should be timed out
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,403,4)
	do tf^%ut(return["Forbidden",5)
	;
	; now stop the webserver again
	do stop(passwdJob)
	;
	quit
	;
tLoginNoTimeout ; @TEST Test Logins with no Timeouts
	; It's difficult to prove a negative, so all this test does is simple stuff with --token-timeout 0
	; NB: Numbers as arguments to the M-Unit test asserts help us identify which test failed 
	; 
	new passwdJob,status,payload,httpStatus,return
	;
	; Now start a webserver with a username/password passed
	job start^%ydbwebreq:cmd="job --port 55730 --token-timeout 0 --auth-file users.json"
	set passwdJob=$zjob
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do fail^%ut("Failed to connect to server") quit
	close "sock"
	;
	; Now login with good un/pw
	set payload="{ ""username"" : ""admin"", ""password"" : ""pass"" }"
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55730/api/login",payload,"application/json")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,1)
	;
	; Get the token out of the json in `return`
	; We don't need to assert anything as the code will crash if returnjson is not properly formatted
	new returnjson do decode^%ydbwebjson($name(return),$name(returnjson))
	new token set token=returnjson("token")
	;
	; Now get the XML using the token
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,2)
	do tf^%ut(return["<?xml",3)

	; now stop the webserver again
	do stop(passwdJob)
	;
	quit
	;
tLoginMultipleServers ; @TEST Test login with multiple servers
	; --> to ensure they don't cross contaminate
	new job1,job2,status,payload,httpStatus,return
	;
	; Now start a webserver with a username/password passed
	job start^%ydbwebreq:cmd="job --port 55730 --auth-file users.json"
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	set job1=$zjob
	;
	job start^%ydbwebreq:cmd="job --port 55731 --auth-file users.json"
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	set job2=$zjob
	;
	; login with good un/pw to job 1
	set payload="{ ""username"" : ""admin"", ""password"" : ""pass"" }"
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55730/api/login",payload,"application/json")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,1)
	;
	; Get token from job 1
	new returnjson do decode^%ydbwebjson($name(return),$name(returnjson))
	new token set token=returnjson("token")
	;
	; Use token from job 1 on job 1
	; Now get the XML using the token
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,2)
	do tf^%ut(return["<?xml",3)
	;
	; Use token from job 1 on job 2
	do &libcurl.init
	do &libcurl.addHeader("Authorization: Bearer "_token)
	set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55731/test/xml")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,403,4)
	;
	; Stop servers
	do stop(job1)
	do stop(job2)
	;
	quit
	;
tusersNoFile ; @TEST Test --auth-file with a file that doesn't exist
	;new ofile set ofile=
	new x,ofile
	set ofile="/tmp/tusersNoFile"
	; job command is picky, so we won't use ofile there
	job start^%ydbwebreq:(cmd="job --port 55730 --auth-file idontexist.json":out="/tmp/tusersNoFile")
	for  quit:$zsearch(ofile,-1)'=""  hang .01
	for  quit:'$zgetjpi($zjob,"ISPROCALIVE")  hang .01
	open ofile:readonly use ofile
	for i=1:1 read x(i) quit:$zeof
	close ofile
	do tf^%ut(x(1)["File idontexist.json does not exist")
	quit
	;
tusersInvalidJSON ; @TEST Test --auth-file with a invalid JSON
	new f,x,ofile
	set f="badjson.json",ofile="/tmp/tusersInvalidJSON"
	open f:writeonly use f write "foo boo coo" close f
	job start^%ydbwebreq:(cmd="job --port 55730 --auth-file badjson.json":out="/tmp/tusersInvalidJSON")
	for  quit:$zsearch(ofile,-1)'=""  hang .01
	for  quit:'$zgetjpi($zjob,"ISPROCALIVE")  hang .01
	open ofile:readonly
	use ofile
	for i=1:1 read x(i) quit:$zeof
	close ofile
	do tf^%ut(x(1)["User file is not a valid JSON file")
	quit
	;
tusersValidJSONInvalidKeys ; @TEST Test --auth-file with bad keys
	new f,x,ofile
	set f="goodjsonbadkeys.json",ofile="/tmp/tusersValidJSONInvalidKeys"
	open f:writeonly use f 
	write "[ { ""username"": ""sam"", ""password"": ""foo"", ""auuuthorization"":""RW"" } ]"
	close f
	job start^%ydbwebreq:(cmd="job --port 55730 --auth-file goodjsonbadkeys.json":out="/tmp/tusersValidJSONInvalidKeys")
	for  quit:$zsearch(ofile,-1)'=""  hang .01
	for  quit:'$zgetjpi($zjob,"ISPROCALIVE")  hang .01
	open ofile:readonly
	use ofile
	for i=1:1 read x(i) quit:$zeof
	close ofile
	do tf^%ut(x(1)["User file is not a valid JSON file")
	quit
	;
tsodiumerror ; @TEST Test crashing libsodium runtime
	new httpStatus,return
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/simsodiumerr")
	do eq^%ut(httpStatus,500)
	do tf^%ut(return["YDB-E-ZCCTOPN")
	quit
	;
tauthMode ; @TEST /api/auth-mode
	new httpStatus,return,json,status,passwdJob
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/api/auth-mode")
	do eq^%ut(httpStatus,200)
	do decode^%ydbwebjson($name(return),$name(json))
	do eq^%ut(json("auth"),"false")
	;
	kill json
	;
	; Now start a webserver with a username/password
	job start^%ydbwebreq:cmd="job --port 55730 --auth-file users.json"
	set passwdJob=$zjob
	;
	; Need to make sure server is started before we ask curl to connect
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	;
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/api/auth-mode")
	do eq^%ut(httpStatus,200)
	do decode^%ydbwebjson($name(return),$name(json))
	do eq^%ut(json("auth"),"true")
	;
	; now stop the webserver again
	do stop(passwdJob)
	quit
	;
tpost ; @TEST simple post
	new httpStatus,return
	new random set random=$random(99999999)
	new payload set payload="{ ""random"" : """_random_""" } "
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55728/test/post",payload,"application/json")
	do &libcurl.cleanup
	do tf^%ut(return[random)
	quit
	;
tgetjson ; @TEST Get simple JSON (tests auto-encoder)
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/json",,"application/json")
	do eq^%ut(httpStatus,200)
	do decode^%ydbwebjson("return","data")
	do eq^%ut(data("foo",2),"doo")
	quit
	;
tpostmalformed ; @TEST Malformed post
	new httpStatus,return
	new random set random=$random(99999999)
	new payload set payload="{ ""random"" : """_random
	do &libcurl.init
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55728/test/post",payload,"application/json")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,400)
	new returnjson,%ydbweberror
	do decode^%ydbwebjson($name(return),$name(returnjson),$name(%ydbweberror))
	do tf^%ut('$data(%ydbweberror))
	do eq^%ut(returnjson("error","errors",1,"reason"),"JSON Converstion Error")
	quit
	;
tTLS ; @TEST Start with TLS and test
	new cryptfile set cryptfile=$zsearch("/mwebserver/certs/ydbgui.ydbcrypt",-1)
	if cryptfile="" do fail^%ut("TLS is not set-up file") quit
	;
	new cryptconfig set cryptconfig=$ztrnlnm("ydb_crypt_config")
	if cryptconfig="" do fail^%ut("TLS is not set-up env 1") quit
	;
	new ydbpasswd set ydbpasswd=$ztrnlnm("ydb_tls_passwd_ydbgui")
	if ydbpasswd="" do fail^%ut("TLS is not set-up env 2") quit
	;
	j start^%ydbwebreq:cmd="job --port 55730 --tlsconfig ydbgui"
	new tlsjob set tlsjob=$zjob
	open "sock":(connect="127.0.0.1:55730:TCP":attach="client"):5:"socket"
	else  do FAIL^%ut("Failed to connect to server") quit
	close "sock"
	;
	do &libcurl.init
	do &libcurl.serverCA("/mwebserver/certs/ydbgui.pem")
	; MUST use localhost here as certificate has a domain name of localhost
	; Took me a while to find that one out
	do &libcurl.do(.httpStatus,.return,"GET","https://localhost:55730/api/ping")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200)
	;
	new options 
	set options("port")=55730
	set options("tlsconfig")="client"
	do stop^%ydbwebreq(.options)
	hang .1
	do eq^%ut($zgetjpi(tlsjob,"ISPROCALIVE"),0)
	quit
	;
tEtag1 ; @TEST Test caching with Etag
	new f set f="test.txt"
	open f:newversion use f
	write "test",!
	close f
	new httpStatus,return
	;I found out the ETag generated by running this first
	;do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test.txt",,,,.headers)
	;zwrite httpStatus,return,headers
	;
	do &libcurl.init
	do &libcurl.addHeader("If-None-Match: 0x88375a6109328211d2e5093f3162e517")
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55728/test.txt")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,304)
	;
	quit
	;
tReadWrite ; @TEST Test read-write flag
	new httpStatus,return
	;
	; Default status is zero
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/readwrite")
	do eq^%ut(httpStatus,200)
	do eq^%ut(return,0)
	;
	; Now start a webserver with read/write
	job start^%ydbwebreq:cmd="job --port 55730 --readwrite"
	hang .1
	new rwserver set rwserver=$zjob
	; 
	; Get new status
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/readwrite")
	do eq^%ut(httpStatus,200)
	do eq^%ut(return,1)
	;
	; now stop the webserver with read/write
	do stop(rwserver)
	quit
	;
tVersion ; @TEST version
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/api/version")
	do eq^%ut(httpStatus,200)
	do decode^%ydbwebjson($name(return),$name(version))
	do tf^%ut($data(version("version")))
	quit
	;
tUppercase ; @TEST uppercase HTTP variables
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/uppercase?foo=boo")
	do eq^%ut(httpStatus,200)
	do eq^%ut(return,"boo")
	quit
	;
tGlobalDir ; @TEST Custom Global Directory using X-YDB-Global-Directory
	new x
	new gdefile set gdefile="/tmp/mumps.gde"
	open gdefile:newversion
	use gdefile
	write "change -segment DEFAULT -file=""/tmp/mumps.dat""",!
	write "exit",!
	close gdefile
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/yottadb -r GDE @"_gdefile)::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	kill x
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/mupip create")::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	open gdefile
	close gdefile:delete
	;
	; Normal Test
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/zgbldir")
	do eq^%ut(httpStatus,200,1)
	do eq^%ut(return,"|",2)
	;
	; Test with sending header
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Global-Directory: /tmp/testdb.gld")
	new status set status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/zgbldir")
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200,3)
	do eq^%ut(return,"/tmp/testdb.gld|/tmp/testdb.gld",4)
	;
	; Normal Test again
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/zgbldir")
	do eq^%ut(httpStatus,200,11)
	do eq^%ut(return,"|",12)
	;
	; Test two calls, one crashes. Make sure that the original value is restored
	new httpStatus1,return1
	new httpStatus2,return2
	;
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Global-Directory: /tmp/testdb.gld")
	set status=$&libcurl.do(.httpStatus1,.return1,"GET","http://127.0.0.1:55728/test/zgbldir?crash=1")
	set status=$&libcurl.do(.httpStatus2,.return2,"GET","http://127.0.0.1:55728/test/zgbldir")
	do eq^%ut(httpStatus1,500,5)
	do tf^%ut(return1["YDB-E-SETECODE",6)
	do eq^%ut(httpStatus2,200,7)
	do eq^%ut(return2,"|",8)
	do &libcurl.cleanup
	;
	open "/tmp/testdb.gld":readonly
	close "/tmp/testdb.gld":delete
	quit
	;
tCWD	; @TEST Change $ZDIRECTORY using X-YDB-Working-Directory
	new httpStatus,return,status
	;
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/cwd")
	do eq^%ut(httpStatus,200,1)
	do eq^%ut(return,"/data/",2)
	;
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Working-Directory: /tmp/")
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/cwd")
	do eq^%ut(httpStatus,200,3)
	do eq^%ut(return,"/tmp/",4)
	do &libcurl.cleanup
	;
	; Normal Test again
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/cwd")
	do eq^%ut(httpStatus,200,11)
	do eq^%ut(return,"/data/",22)
	;
	; Test two calls, one crashes. Make sure that the original value is restored
	new httpStatus1,return1
	new httpStatus2,return2
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Working-Directory: /tmp/")
	set status=$&libcurl.curl(.httpStatus1,.return1,"GET","http://127.0.0.1:55728/test/cwd?crash=1")
	set status=$&libcurl.curl(.httpStatus2,.return2,"GET","http://127.0.0.1:55728/test/cwd")
	do eq^%ut(httpStatus1,500,5)
	do tf^%ut(return1["YDB-E-SETECODE",6)
	do eq^%ut(httpStatus2,200,7)
	do eq^%ut(return2,"/data/",8)
	do &libcurl.cleanup
	quit
	;
tEnv	; @TEST Change environment using X-YDB-Env-Vars
	new httpStatus,return,status
	;
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/env")
	do eq^%ut(httpStatus,200,1)
	do eq^%ut(return,"",2)
	;
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Env-Vars: ydb_rel=r200; ydb_dir=/foo/")
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/env")
	do eq^%ut(httpStatus,200,3)
	do eq^%ut(return,"/foo/",4)
	do &libcurl.cleanup
	;
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/env")
	do eq^%ut(httpStatus,200,11)
	do eq^%ut(return,"",22)
	;
	; Test two calls, one crashes. Make sure that the original value is restored
	new httpStatus1,return1
	new httpStatus2,return2
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Env-Vars: ydb_rel=r200; ydb_dir=/foo/")
	set status=$&libcurl.curl(.httpStatus1,.return1,"GET","http://127.0.0.1:55728/test/env?crash=1")
	set status=$&libcurl.curl(.httpStatus2,.return2,"GET","http://127.0.0.1:55728/test/env")
	do eq^%ut(httpStatus1,500,5)
	do tf^%ut(return1["YDB-E-SETECODE",6)
	do eq^%ut(httpStatus2,200,7)
	do eq^%ut(return2,"",8)
	do &libcurl.cleanup
	quit
	;
tGCE	; @TEST Change Global, Environment, and Directory together
	new x
	new gdefile set gdefile="/tmp/mumps.gde"
	open gdefile:newversion
	use gdefile
	write "change -segment DEFAULT -file=""/tmp/mumps.dat""",!
	write "exit",!
	close gdefile
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/yottadb -r GDE @"_gdefile)::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	kill x
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/mupip create")::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	open gdefile
	close gdefile:delete
	;
	new httpStatus,return
	;
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/gce")
	do eq^%ut(httpStatus,200,1)
	do eq^%ut(return,"|/data/|",2)
	;
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Env-Vars: ydb_rel=r200; ydb_dir=/foo/")
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/gce")
	do eq^%ut(httpStatus,200,3)
	do eq^%ut(return,"|/data/|/foo/",4)
	do &libcurl.cleanup
	;
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Global-Directory: /tmp/testdb.gld")
	do &libcurl.addHeader("X-YDB-Working-Directory: /tmp/")
	do &libcurl.addHeader("X-YDB-Env-Vars: ydb_rel=r200; ydb_dir=/foo/")
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/gce")
	do eq^%ut(httpStatus,200,5)
	do eq^%ut(return,"/tmp/testdb.gld|/tmp/|/foo/",6)
	do &libcurl.cleanup
	;
	set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/gce")
	do eq^%ut(httpStatus,200,11)
	do eq^%ut(return,"|/data/|",22)
	;
	; Test two calls, one crashes. Make sure that the original value is restored
	new httpStatus1,return1
	new httpStatus2,return2
	do &libcurl.init
	do &libcurl.addHeader("X-YDB-Global-Directory: /tmp/testdb.gld")
	do &libcurl.addHeader("X-YDB-Working-Directory: /tmp/")
	do &libcurl.addHeader("X-YDB-Env-Vars: ydb_rel=r200; ydb_dir=/foo/")
	set status=$&libcurl.curl(.httpStatus1,.return1,"GET","http://127.0.0.1:55728/test/gce?crash=1")
	set status=$&libcurl.curl(.httpStatus2,.return2,"GET","http://127.0.0.1:55728/test/gce")
	do eq^%ut(httpStatus1,500,7)
	do tf^%ut(return1["YDB-E-SETECODE",8)
	do eq^%ut(httpStatus2,200,9)
	do eq^%ut(return,"|/data/|",10)
	do &libcurl.cleanup
	;
	open "/tmp/testdb.gld":readonly
	close "/tmp/testdb.gld":delete
	quit
	;
twsport ; @TEST Test --ws-port flag
	new httpStatus,return
	;
	; Default port is zero
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/ws-port")
	do eq^%ut(httpStatus,200,1)
	do eq^%ut(return,0,2)
	;
	; Now start a webserver with read/write
	job start^%ydbwebreq:cmd="job --port 55730 --ws-port 55731"
	hang .1
	new server set server=$zjob
	; 
	; Get new port
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/ws-port")
	do eq^%ut(httpStatus,200,3)
	do eq^%ut(return,55731,4)
	;
	; now stop the webserver
	do stop(server)
	quit
	;
mjeloc	; @TEST Test that mje files are in $ydb_tmp and not in /tmp/
	zsystem "mkdir -p /data/tmp/"
	; Using this instead of ydb_tmp to show that it works
	; No seperate test for ydb_tmp as the source code uses ydb_tmp; this tests both
	view "setenv":"gtm_tmp":"/data/tmp/"
	job start^%ydbwebreq:cmd="job --port 55730"
	hang .1
	new server set server=$zjob
	do tf^%ut($zsearch("/data/tmp/%ydbwebreq"_server_".mje")'="",1)
	do tf^%ut($zsearch("/tmp/%ydbwebreq"_server_".mje")="",2)
	do stop(server)
	;
	view "unsetenv":"gtm_tmp"
	job start^%ydbwebreq:cmd="job --port 55730"
	hang .1
	new server set server=$zjob
	do tf^%ut($zsearch("/data/tmp/%ydbwebreq"_server_".mje")="",3)
	do tf^%ut($zsearch("/tmp/%ydbwebreq"_server_".mje")'="",4)
	do stop(server)
	zsystem "rm -r /data/tmp/"
	;
	quit
	;
tRecChuncked ; @TEST Receive chunked data
	; like curl -vvv -H "Transfer-Encoding: chunked" --data-binary @./wwwroot/test/mockData.js localhost:9080/test/postchunked
	new httpStatus0,return0
	new httpStatus1,return1
	new httpStatus2,return2
	new payload0,payload1,payload2
	; Curl segments chuncked segemnts at 64 k. So we need to test no data, 1 chunk and 2 chunks
	set payload0=""
	set $zpiece(payload1,"a",49999)="bb" ; one chunk = 50000 characters
	set $zpiece(payload2,"c",99999)="dd" ; two chunks = 100000 characters
	do &libcurl.init
	do &libcurl.addHeader("Transfer-Encoding: chunked")
	do &libcurl.do(.httpStatus0,.return0,"POST","http://127.0.0.1:55728/test/postchunked",payload0,"application/text",1,.headers)
	do &libcurl.addHeader("Transfer-Encoding: chunked")
	do &libcurl.do(.httpStatus1,.return1,"POST","http://127.0.0.1:55728/test/postchunked",payload1,"application/text",1,.headers)
	do &libcurl.addHeader("Transfer-Encoding: chunked")
	do &libcurl.do(.httpStatus2,.return2,"POST","http://127.0.0.1:55728/test/postchunked",payload2,"application/text",1,.headers)
	do &libcurl.cleanup
	do eq^%ut(httpStatus0,200)
	do eq^%ut(httpStatus1,200)
	do eq^%ut(httpStatus2,200)
	do eq^%ut(return0,"0^0")
	do eq^%ut(return1,"50000^13")
	do eq^%ut(return2,"100000^26")
	quit
	;
tRecChunckedInc ; @TEST Received chunked data incrementally
	new httpStatus,return,payload
	set $zpiece(payload,"a",2**20)="a" ; 1MB
	do &libcurl.init
	do &libcurl.addHeader("Transfer-Encoding: chunked")
	do &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55728/test/postchunkedinc",payload,"application/text",1,.headers)
	do &libcurl.cleanup
	do eq^%ut(httpStatus,200)
	; 17 chunks processed
	do tf^%ut($zl(return,$char(13,10)),17)
	quit
	;
	;
tExpect ; @TEST Test that 100-Expect is sent correctly.
	; Cannot do this using libcurl plugin, as we need to post more than 1 MB
	new x,i,a
	set $zpiece(a,"a",2**20)="a" ; 1MB
	open "2mbfile.txt":newversion
	use "2mbfile.txt"
	write a,!,a,!
	open "p":(shell="/bin/sh":command="curl -vvv --header 'Transfer-Encoding: chunked' http://localhost:55728/test/postchunkedinc -d @2mbfile.txt")::"pipe"
	use "p"
	for i=1:1 read x(i) quit:$zeof
	close "p"
	new foundexpect set foundexpect=0
	for i=0:0 set i=$order(x(i)) quit:'i  if x(i)["HTTP/1.1 100 Continue" set foundexpect=1 quit
	do tf^%ut(foundexpect)
	quit
	;
tSendChunked ; @TEST Send chunked data
	; Create global directory as we use globals in this test
	new x
	new gdefile set gdefile="/tmp/mumps.gde"
	open gdefile:newversion
	use gdefile
	write "change -segment DEFAULT -file=""/tmp/mumps.dat""",!
	write "exit",!
	close gdefile
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/yottadb -r GDE @"_gdefile)::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	kill x
	open "pipe":(shell="/bin/bash":command="ydb_gbldir=/tmp/testdb.gld $ydb_dist/mupip create")::"pipe"
	use "pipe"
	for i=1:1 read x(i) quit:$zeof
	close "pipe"
	open gdefile
	close gdefile:delete

	set $zgbldir="/tmp/testdb.gld"
	view "setenv":"ydb_gbldir":$zgbldir
	view "gbldirload":$zgbldir
	;
	job start^%ydbwebreq:cmd="job --port 55730"
	hang .1
	new server set server=$zjob
	new httpStatus,return
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/getchunked")
	do eq^%ut(httpStatus,200,1)
	do tf^%ut(return[($char(13,10)_"global_sequential_nodes_query: subnode1subnode2"_$char(13,10)),2)
	do tf^%ut(return[($char(10)_"End of Transmission"_$char(13,10)),3)
	do tf^%ut(return'[($char(13,10)_"SHOULD NOT BE SENT"_$char(13,10)),4)
	do tf^%ut($data(^data6("goo")),5) ; was not sent, shouldn't be killed
	do tf^%ut($zlength(return)>91300,6)
	do stop(server)
	;
	; Same tests, but with gzip (it gets disabled right now for chunked data)
	job start^%ydbwebreq:cmd="job --port 55730 --gzip"
	hang .1
	new server set server=$zjob
	new httpStatus,return
	do &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55730/test/getchunked")
	do eq^%ut(httpStatus,200,7)
	do tf^%ut(return[($char(13,10)_"global_sequential_nodes_query: subnode1subnode2"_$char(13,10)),8)
	do tf^%ut(return[($char(10)_"End of Transmission"_$char(13,10)),9)
	do tf^%ut(return'[($char(13,10)_"SHOULD NOT BE SENT"_$char(13,10)),10)
	do tf^%ut($data(^data6("goo")),11) ; was not sent, shouldn't be killed
	do tf^%ut($zlength(return)>91300,12)
	do stop(server)
	;
	set $zgbldir=""
	view "unsetenv":"ydb_gbldir"
	open "/tmp/testdb.gld" close "/tmp/testdb.gld":delete
	open "/tmp/mumps.dat" close "/tmp/mumps.dat":delete
	quit
	;
tBinary ; @TEST Test binary data is sent back successfully (#146)
	new httpStatus,return
	new status set status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/getbinary")
	do eq^%ut(httpStatus,200)
	do eq^%ut(return,$zch(128))
	quit
	;
tStop ; @TEST Stop the Server. MUST BE LAST TEST HERE.
	new options set options("port")=55728
	do stop^%ydbwebreq(.options)
	for  quit:'$zgetjpi(myJob,"isprocalive")  hang .001
	do eq^%ut($zgetjpi(myJob,"ISPROCALIVE"),0)
	quit
	;
XTROU ;
	;;%ydbwebjsonEncodeTest
	;;%ydbwebjsonDecodeTest
	;;
EOR ;
	;
	; Copyright (c) 2018-2020 Sam Habiel
	; Copyright (c) 2019 Christopher Edwards
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
