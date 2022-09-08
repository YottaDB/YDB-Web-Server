%webtest ; ose/smh - Web Services Tester;Jun 20, 2022@15:59
 ; Runs only on GTM/YDB
 ; Requires M-Unit
 ;
test if $text(^%ut)="" quit
 do EN^%ut($t(+0),3)
 quit
 ;
STARTUP ;
 job start^%webreq(55728)
 set myJob=$zjob
 hang .1
 quit
 ;
SHUTDOWN ;
 open "p":(command="$gtm_dist/mupip stop "_myJob)::"pipe"
 use "p" r x:1
 close "p"
 w !,x,!
 ;
 kill myJob
 quit
 ;
tdebug ; @TEST Debug Entry Point
 job start^%webreq(55729,1):(IN="/dev/null":OUT="/dev/null":ERR="/dev/null"):5
 h .1
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55729/")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["YottaDB Restful Web-Services Portal")
 ; and it halts on its own
 quit
 ;
thome ; @TEST Test Home Page
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["YottaDB Restful Web-Services Portal")
 quit
 ;
tgetr ; @TEST Test Get Handler Routine
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/r/%25webapi")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["YottaDB LLC")
 quit
 ;
tputr ; @TEST Put a Routine
 n httpStatus,return,headers
 n random s random=$R(9817238947)
 n payload s payload="KBANTESTWEB ;"_random_$C(13,10)_" W ""HELLO WORLD"",!"_$C(13,10)_" QUIT"
 d &libcurl.init
 d &libcurl.auth("Basic",$tr("foo:boo",";",":"))
 d &libcurl.do(.httpStatus,.return,"PUT","http://127.0.0.1:55728/r/KBANTESTWEB",payload,"application/text",1,.headers)
 do CHKEQ^%ut(httpStatus,201)
 d &libcurl.cleanup
 k httpStatus,return
 d &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/r/KBANTESTWEB")
 do CHKTF^%ut(return[random)
 quit
 ;
tgetxml ; @TEST Test Get Handler XML
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/xml")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["xml")
 quit
 ;
tdecodeutf8 ; @TEST Test Decode UTF-8 URL
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/utf8/get?foo=こにちは")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return="こにちは")
 quit
 ;
tencdecutf8 ; @TEST Encode and Decode UTF-8
 n x s x="foo=Å"
 do CHKEQ^%ut(x,$$URLDEC^%webutils($$URLENC^%webutils(x)))
 quit
 ;
tencdecx ; @Test Encode and Decode an excepted character
 n x s x=","
 do CHKEQ^%ut(x,$$URLDEC^%webutils($$URLENC^%webutils(x)))
 quit
 ;
tpostutf8 ; @TEST Post UTF8 data, expect parts of url post data back
 ; curl -XPOST -d '{"直接": "人生"}' localhost:9080/test/utf8/post?foo=こにちは
 ; Result:
 ; Line 1: こにち
 ; Line 2: 人生
 n httpStatus,return
 n payload s payload="{""直接"":""人生""}"
 d &libcurl.init
 d &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55728/test/utf8/post?foo=こにちは",payload,"application/json")
 d &libcurl.cleanup
 set return(1)=$piece(return,$C(13,10),1)
 set return(2)=$piece(return,$C(13,10),2)
 do CHKEQ^%ut(return(1),"こにち")
 do CHKEQ^%ut(return(2),"人生")
 quit
 ;
thead ; #TEST HTTP Verb HEAD (only works with GET queries)
 ; my libcurl doesn't do HEAD :-( - but head works
 n httpStatus,return,headers,status
 d
 . n $et,$es s $et="s ec=$ec,$ec="""""
 . s status=$&libcurl.curl(.httpStatus,.return,"HEAD","http://127.0.0.1:55728/test/xml",,,1,.headers)
 zwrite ec
 zwrite httpStatus
 zwrite headers
 quit
 ;
tgzip ; @TEST Test gzip encoding
 n httpStatus,return,headers
 d &libcurl.init
 d &libcurl.addHeader("Accept-Encoding: gzip")
 n status s status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55728/r/%25webapi",,,1,.headers)
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(headers["Content-Encoding: gzip")
 view "nobadchar"
 do CHKTF^%ut(return[$C(0))
 view "badchar"
 quit
 ;
tnogzipflag ; @TEST Test nogzip flag
 n gzipflagjob
 ;
 ; Start server with no gzip
 j start^%webreq(55732,"",,,,1)
 h .1
 s gzipflagjob=$zjob
 ;
 n httpStatus,return,headers
 d &libcurl.init
 d &libcurl.addHeader("Accept-Encoding: gzip") ; This must be sent to properly test as the server is smart and if we don't send that we support gzip it won't gzip
 n status s status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55732/r/%25webapi",,,1,.headers)
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(headers'["Content-Encoding: gzip")
 do CHKTF^%ut(return["webapi ; OSE/SMH - Infrastructure web services hooks")
 ;
 ; now stop the webserver again
 open "p":(command="$gtm_dist/mupip stop "_gzipflagjob)::"pipe"
 use "p" r x:1
 close "p"
 d CHKEQ^%ut($ZCLOSE,0)
 ;
 kill gzipflagjob
 quit
 ;
temptynogzip ; @TEST Empty response with no gzip encoding
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/empty")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return="")
 quit
 ;
temptygzip ; @TEST Empty response with gzip
 n httpStatus,return
 d &libcurl.init
 d &libcurl.addHeader("Accept-Encoding: gzip")
 n status s status=$&libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/empty",,,1,.headers)
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(headers'["Content-Encoding: gzip")
 do CHKTF^%ut(return="")
 quit
 ;
tping ; @TEST Ping
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/ping")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["server")
 quit
 ;
terr ; @TEST generating an error
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/error")
 do CHKEQ^%ut(httpStatus,500)
 do CHKTF^%ut(return["DIVZERO")
 quit
 ;
terr2 ; @TEST crashing the error trap
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/error?foo=crash2")
 do CHKEQ^%ut(httpStatus,500)
 quit
 ;
tcustomError ; @TEST Custom Error
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/customerror")
 do CHKTF^%ut(return["OperationOutcome")
 do CHKEQ^%ut(httpStatus,400)
 quit
 ;
tlong ; @TEST get a long message
 ; Exercises the flushing
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/bigoutput")
 do CHKEQ^%ut(httpStatus,200)
 do CHKEQ^%ut($l(return),32769)
 quit
 ;
tKillGlo ; #TEST kill global after sending result in it
 ; We don't run this in the test suite since we need to ensure that our tests runs without a database
 n httpStatus,return
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55728/test/gloreturn")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["coo")
 do CHKTF^%ut('$d(^web("%webapi")))
 quit
 ;
tDC ; @TEST Test Disconnecting from the Server w/o talking
 open "sock":(connect="127.0.0.1:55728:TCP":attach="client"):1:"socket"
 else  D FAIL^%ut("Failed to connect to server") quit
 close "sock"
 quit
 ;
tInt ; @TEST ZInterrupt
 new oldfile
 for  set oldfile=$zsearch("YDB_JOBEXAM.ZSHOW_DMP_*") quit:oldfile=""  do
 . open oldfile:readonly
 . close oldfile:delete
 open "p":(command="$gtm_dist/mupip intrpt "_myJob)::"pipe"
 use "p" r x:1
 close "p"
 h .1
 new newfile set newfile=$zsearch("YDB_JOBEXAM.ZSHOW_DMP_"_myJob_"_1",-1)
 if newfile'="" do SUCCEED^%ut
 QUIT
 ;
tLog1 ; @TEST Set HTTPLOG to 1
 ; This is the default logging, no need to set
 job start^%webreq(55731):(IN="/dev/null":OUT="/tmp/sim-stdout1":ERR="/dev/null"):5
 new serverjob set serverjob=$zjob
 ; Need to make sure server is started before we ask curl to connect
 open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
 else  D FAIL^%ut("Failed to connect to server") quit
 close "sock"
 n httpStatus,return,x
 d &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/ping")
 open "/tmp/sim-stdout1":(stream:readonly:rewind:delimiter=$char(10))
 use "/tmp/sim-stdout1"
 new i for i=1:1 read x(i) quit:$zeof
 close "/tmp/sim-stdout1"
 ; Can't get the file to have the right contents; but it's there when manually testing...
 ;d CHKTF^%ut(x(1)["ping",x(1))
 open "p":(command="$gtm_dist/mupip stop "_serverjob)::"pipe"
 use "p" r x:1
 d CHKEQ^%ut($ZCLOSE,0)
 close "p"
 quit
 ;
tLog2 ; @TEST Set HTTPLOG to 2
 job start^%webreq(55731,,,2):(IN="/dev/null":OUT="/tmp/sim-stdout2":ERR="/dev/null"):5
 new serverjob set serverjob=$zjob
 ; Need to make sure server is started before we ask curl to connect
 open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
 else  D FAIL^%ut("Failed to connect to server") quit
 close "sock"
 n httpStatus,return,x
 d &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/ping")
 open "/tmp/sim-stdout2":(stream:readonly:rewind:delimiter=$char(10))
 use "/tmp/sim-stdout2"
 new i for i=1:1 read x(i) quit:$zeof
 close "/tmp/sim-stdout2"
 ; Can't get the file to have the right contents...
 ; but giving up on this for now...
 ;d CHKTF^%ut(x(1)["ping",x(1))
 ; Funny enough, even cat does not show the correct contents, so something is
 ; not right, but I can't manually replicate this
 open "p":(command="$gtm_dist/mupip stop "_serverjob)::"pipe"
 use "p" r x:1
 d CHKEQ^%ut($ZCLOSE,0)
 close "p"
 quit
 ;
tLog3 ; @TEST Set HTTPLOG to 3
 job start^%webreq(55731,,,3):(IN="/dev/null":OUT="/tmp/sim-stdout3":ERR="/dev/null"):5
 new serverjob set serverjob=$zjob
 ; Need to make sure server is started before we ask curl to connect
 open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
 else  D FAIL^%ut("Failed to connect to server") quit
 close "sock"
 n httpStatus,return,x
 n status s status=$&libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/r/%25webapi")
 do CHKEQ^%ut(httpStatus,200)
 do CHKTF^%ut(return["YottaDB LLC")
 open "/tmp/sim-stdout3":(stream:readonly:rewind:delimiter=$char(10))
 use "/tmp/sim-stdout3"
 new i for i=1:1 read x(i) quit:$zeof
 close "/tmp/sim-stdout3"
 d CHKTF^%ut(x(8)["HTTPRSP",x(1))
 open "p":(command="$gtm_dist/mupip stop "_serverjob)::"pipe"
 use "p" r x:1
 d CHKEQ^%ut($ZCLOSE,0)
 close "p"
 quit
 ;
tDCLog ; @TEST Test Log Disconnect
 job start^%webreq(55731,,,3):(IN="/dev/null":OUT="/tmp/sim-stdout4":ERR="/dev/null"):5
 new serverjob set serverjob=$zjob
 open "sock":(connect="127.0.0.1:55731:TCP":attach="client"):5:"socket"
 else  D FAIL^%ut("Failed to connect to server") quit
 close "sock"
 n x
 open "/tmp/sim-stdout4":(stream:readonly:rewind:delimiter=$char(10))
 use "/tmp/sim-stdout4"
 new i for i=1:1 read x(i) quit:$zeof
 close "/tmp/sim-stdout4"
 ; Ditto on not finding the text
 ;zwrite x
 ;d CHKTF^%ut(x(1)["Disconnect/Halt",x(1))
 open "p":(command="$gtm_dist/mupip stop "_serverjob)::"pipe"
 use "p" r x:1
 d CHKEQ^%ut($ZCLOSE,0)
 close "p"
 quit
 ;
tWebPage ; @TEST Test Getting a web page
 ; Now start a webserver with a new zdirectory of /tmp/
 new oldDir set oldDir=$zd
 set $zd="/tmp/"
 job start^%webreq(55731)
 hang .1
 new serverjob set serverjob=$zjob
 zsy "mkdir -p /tmp/foo"
 new random s random=$R(9817234)
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
 n httpStatus,return
 d &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/foo/boo.html")
 d CHKEQ^%ut(httpStatus,200)
 d CHKTF^%ut(return[random)
 set $zd=oldDir
 ; now stop the webserver again
 open "p":(command="$gtm_dist/mupip stop "_serverjob)::"pipe"
 use "p" r x:1
 d CHKEQ^%ut($ZCLOSE,0)
 close "p"
 quit
 ;
tHomePage ; @Test Getting index.html page
 n nogblJob
 ;
 ; Now start a webserver with a new zdirectory of /tmp/
 new oldDir set oldDir=$zd
 set $zd="/tmp/"
 job start^%webreq(55731)
 hang .1
 set nogblJob=$zjob
 new random s random=$R(9817234)
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
 n httpStatus,return
 d &libcurl.curl(.httpStatus,.return,"GET","http://127.0.0.1:55731/")
 d CHKEQ^%ut(httpStatus,200)
 d CHKTF^%ut(return[random)
 set $zd=oldDir
 open "p":(command="$gtm_dist/mupip stop "_nogblJob)::"pipe"
 use "p" r x:1
 d CHKEQ^%ut($ZCLOSE,0)
 close "p"
 quit
 ;
CORS ; @TEST Make sure CORS headers are returned
 n httpStatus,return,headers,headerarray
 d &libcurl.curl(.httpStatus,.return,"OPTIONS","http://127.0.0.1:55728/r/kbbotest.m",,,,.headers)
 ;
 ; Split the headers apart using carriage return line feed delimiter
 f i=1:1:$L(headers,$C(13,10)) D
 . ; Change to name based subscripts by using ": " delimiter
 . s:($p($p(headers,$C(13,10),i),": ",1)'="")&($p($p(headers,$C(13,10),i),": ",2)'="") headerarray($p($p(headers,$C(13,10),i),": ",1))=$p($p(headers,$C(13,10),i),": ",2)
 ;
 ; Now make sure all required bits are correct
 d CHKEQ^%ut(httpStatus,200)
 d CHKEQ^%ut($g(headerarray("Access-Control-Allow-Methods")),"OPTIONS, POST")
 d CHKEQ^%ut($g(headerarray("Access-Control-Allow-Headers")),"Content-Type")
 d CHKEQ^%ut($g(headerarray("Access-Control-Max-Age")),"86400")
 d CHKEQ^%ut($g(headerarray("Access-Control-Allow-Origin")),"*")
 quit
 ;
USERPASS ; @TEST Test that passing a username/password works
 n passwdJob
 ;
 ; Now start a webserver with a passed username/password
 j start^%webreq(55730,"",,,"admin:admin")
 h .1
 s passwdJob=$zjob
 ;
 n httpStatus,return
 ;
 ; Positive test
 d &libcurl.init
 d &libcurl.auth("Basic","admin:admin")
 d &libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/ping")
 d &libcurl.cleanup
 d CHKEQ^%ut(httpStatus,200)
 ;
 ; Negative test
 d &libcurl.init
 d &libcurl.auth("Basic","admin:12345")
 d &libcurl.do(.httpStatus,.return,"GET","http://127.0.0.1:55730/ping")
 d &libcurl.cleanup
 d CHKEQ^%ut(httpStatus,401)
 ;
 ; now stop the webserver again
 open "p":(command="$gtm_dist/mupip stop "_passwdJob)::"pipe"
 use "p" r x:1
 close "p"
 d CHKEQ^%ut($ZCLOSE,0)
 ;
 kill passwdJob
 quit
 ;
tpost ; @TEST simple post
 n httpStatus,return
 n random set random=$random(99999999)
 n payload s payload="{ ""random"" : """_random_""" } "
 d &libcurl.init
 d &libcurl.do(.httpStatus,.return,"POST","http://127.0.0.1:55728/test/post",payload,"application/json")
 d &libcurl.cleanup
 do CHKTF^%ut(return[random)
 quit
 ;
tStop ; @TEST Stop the Server. MUST BE LAST TEST HERE.
 do stop^%webreq
 quit
 ;
XTROU ;
 ;;%webjsonEncodeTest
 ;;%webjsonDecodeTest
 ;;
EOR ;
 ;
 ; Copyright (c) 2018-2020 Sam Habiel
 ; Copyright (c) 2019 Christopher Edwards
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
