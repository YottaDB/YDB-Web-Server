%ydbwebapi ; OSE/SMH - Infrastructure web services hooks;Jun 20, 2022@14:45
 ;
R ; GET /test/r/{routine} Mumps Routine
 S HTTPRSP("mime")="text/plain; charset=utf-8"
 N RTN S RTN=$G(HTTPARGS("routine"))
 N OFF,I
 I RTN]""&($T(^@RTN)]"") F I=1:1 S OFF="+"_I,LN0=OFF_"^"_RTN,LN=$T(@LN0) Q:LN=""  S HTTPRSP(I)=LN_$C(13,10)
 E  K HTTPRSP("mime") D setError^%ydbwebutils(404,"Routine not found")
 QUIT
 ;
PR ; PUT /test/r/{routine} Mumps Routine
 S HTTPRSP("mime")="text/plain; charset=utf-8" ; Character set of the return URL
 N PARSED ; Parsed array which stores each line on a separate node.
 N BODY M BODY=HTTPREQ("body")
 D PARSE10^%ydbwebutils(.BODY,.PARSED) ; Parser
 N DIE,XCN S DIE="PARSED(",XCN=0
 N RN S RN=HTTPARGS("routine")
 Q:$E(RN,1,4)'="KBAN"  ; Just for this server, don't do this.
 N %,%F,%I,%N,SP,$ETRAP
 S $ETRAP="S $ECODE="""" Q"
 S %I=$I,SP=" ",%F=$P($$SRCDIR^%RSEL," ")_"/"_$TR(RN,"%","_")_".m"
 O %F:newversion U %F
 F  S XCN=$O(@(DIE_XCN_")")) Q:XCN'>0  S %=@(DIE_XCN_")") Q:$E(%,1)="$"  I $E(%)'=";" W %,!
 C %F
 ZLINK RN
 U %I
 S HTTPLOC="/test/r/"_RN
 QUIT
 ;
err ; GET /test/error Force M Error
 I $G(httpargs("foo"))="crash2" S %webcrash2=1 ; crash the error trap
 D err1
 QUIT
err1 ;
 N X S X=1/0
 ;
bigoutput ; GET /test/bigoutput - Used by Unit Tests to ensure large output is handled appropriately
 n a,b,c
 s $p(a,"a",2**10)="a"
 n i for i=1:1:32 s httprsp(i)=a
 s httprsp(32)=$e(httprsp(32),1,$l(httprsp(32))-1)
 s b=$c(13,10)
 s httprsp(33)=b
 s httprsp("mime")="text/plain; charset=utf-8" ; type of data to send browser
 quit
 ;
gloreturn ; GET /test/gloreturn - Used by Unit Tests to ensure Global deleted properly
 s httprsp=$name(^web("%ydbwebapi"))
 s @httprsp="coo"_$c(13,10)
 s @httprsp@(1)="boo"_$c(13,10)
 s @httprsp@(2)="foo"_$c(13,10)
 s httprsp("mime")="text/plain; charset=utf-8" ; type of data to send browser
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
 set httprsp(1)=$extract(httpargs("foo"),1,3)_$C(13,10)
 set httprsp(2)=$get(httpreq("json","直接"))
 set httprsp("mime")="text/plain; charset=UTF-8"
 set httploc="test/utf8/post?foo="_httpargs("foo")
 quit
 ;
ping ; GET /ping writes out a ping response
 set httprsp("self")=$job
 set httprsp("self","\s")=""
 set httprsp("server")=PPID
 set httprsp("server","\s")=""
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
 n errarr
 s errarr("resourceType")="OperationOutcome"
 s errarr("issue",1,"severity")="error"
 s errarr("issue",1,"code")="processing"
 s errarr("issue",1,"diagnostics")="Test message"
 d customError^%ydbwebutils(400,.errarr)
 quit
 ;
empty(r,a) ; GET /test/empty. Used For Unit Tests
 S httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
 s r=""
 QUIT
 ;
posttest ; POST /test/post Simple test for post
 S httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
 S httprsp="/path/"_httpreq("json","random")_"/1" ; Stored URL
 S httploc=httprsp
 quit
 ;
readwritetest ; GET /test/readwrite Tests readwrite flag
 set httprsp("mime")="text/plain; charset=utf-8" ; Character set of the return URL
 set httprsp=HTTPREADWRITE ; 0 or 1
 quit
 ;
FILESYS(ARGPATH) ; Handle reads from File system.
 ; Ensure Directory has a trailing slash
 ; Otherwise a directory like $ydb_dist/plugin/etc/ydbgui is not readable
 I DIRECTORY'="",$E(DIRECTORY,$L(DIRECTORY))'="/" S DIRECTORY=DIRECTORY_"/"
 ;
 ; get the actual path
 N PATH S PATH=DIRECTORY_ARGPATH
 ;
 ; GT.M errors out on file no found
 N $ET S $ET="G FILESYSE"
 ;
 ; Fixed prevents Reads to terminators on SD's. CHSET makes sure we don't analyze UTF.
 O PATH:(REWIND:READONLY:FIXED:CHSET="M")
 ;
 ; Get mime type
 ; This isn't complete, by any means; it just grabs the most likely types to be
 ; found on an M Web Server. A few common Microsoft types are supported, but
 ; few other vendor-specific types are. Also, there are a few Mumps-centric
 ; types added below (under the x- prefix). If it's an unrecognized file
 ; extension, it's set to text.
 new MIMELKUP
 set MIMELKUP("aif")="audio/aiff"
 set MIMELKUP("aiff")="audio/aiff"
 set MIMELKUP("au")="audio/basic"
 set MIMELKUP("avi")="video/avi"
 set MIMELKUP("css")="text/css; charset=utf-8"
 set MIMELKUP("csv")="text/csv; charset=utf-8"
 set MIMELKUP("doc")="application/msword"
 set MIMELKUP("gif")="image/gif"
 set MIMELKUP("htm")="text/html; charset=utf-8"
 set MIMELKUP("html")="text/html; charset=utf-8"
 set MIMELKUP("ico")="image/x-icon"
 set MIMELKUP("jpe")="image/jpeg"
 set MIMELKUP("jpeg")="image/jpeg"
 set MIMELKUP("jpg")="image/jpeg"
 set MIMELKUP("js")="application/javascript"
 set MIMELKUP("kid")="text/x-mumps-kid; charset=utf-8"
 set MIMELKUP("m")="text/x-mumps; charset=utf-8"
 set MIMELKUP("mov")="video/quicktime"
 set MIMELKUP("mp3")="audio/mpeg3"
 set MIMELKUP("pdf")="application/pdf"
 set MIMELKUP("png")="image/png"
 set MIMELKUP("ppt")="application/vnd.ms-powerpoint"
 set MIMELKUP("ps")="application/postscript"
 set MIMELKUP("qt")="video/quicktime"
 set MIMELKUP("svg")="image/svg+xml"
 set MIMELKUP("tex")="application/x-tex"
 set MIMELKUP("tif")="image/tiff"
 set MIMELKUP("tiff")="image/tiff"
 set MIMELKUP("txt")="text/plain; charset=utf-8"
 set MIMELKUP("log")="text/plain; charset=utf-8"
 set MIMELKUP("wav")="audio/wav"
 set MIMELKUP("xls")="application/vnd.ms-excel"
 set MIMELKUP("zip")="application/zip"
 set MIMELKUP("woff")="font/woff"
 set MIMELKUP("woff2")="font/woff2"
 set MIMELKUP("ttf")="font/ttf"
 set MIMELKUP("eot")="font/eot"
 set MIMELKUP("otf")="font/otf"
 new EXT set EXT=$PIECE(PATH,".",$LENGTH(PATH,"."))
 if $DATA(MIMELKUP(EXT)) set HTTPRSP("mime")=MIMELKUP(EXT)
 else  set HTTPRSP("mime")=MIMELKUP("txt")
 ;
 ; Read operation
 U PATH
 N C S C=1
 N X F  R X#4079:0 S HTTPRSP(C)=X,C=C+1 Q:$ZEOF
 C PATH
 ;
 ; Create ETag
 N ETAG S ETAG=""
 F C=0:0 S C=$O(HTTPRSP(C)) Q:'C  S ETAG=$ZYHASH(ETAG_HTTPRSP(C))
 set HTTPRSP("ETag")=ETAG
 ; 
 QUIT
 ;
FILESYSE ; 500
 S $EC=""
 D setError^%ydbwebutils("500",$ZS)
 QUIT
 ;
 ; Copyright (c) 2013-2020 Sam Habiel
 ; Copyright (c) 2018 Kenneth McGlothlen
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
