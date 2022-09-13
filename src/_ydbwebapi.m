%ydbwebapi ; OSE/SMH - Infrastructure web services hooks;Jun 20, 2022@14:45
 ;
R(RESULT,ARGS) ; [Public] GET /r/{routine} Mumps Routine
 S RESULT("mime")="text/plain; charset=utf-8"
 N RTN S RTN=$G(ARGS("routine"))
 N OFF,I
 I RTN]""&($T(^@RTN)]"") F I=1:1 S OFF="+"_I,LN0=OFF_"^"_RTN,LN=$T(@LN0) Q:LN=""  S RESULT(I)=LN_$C(13,10)
 E  K RESULT("mime") D setError^%ydbwebutils(404,"Routine not found")
 QUIT
 ;
PR(ARGS,BODY,RESULT) ; [Public] PUT /r/{routine} Mumps Routine
 S HTTPRSP("mime")="text/plain; charset=utf-8" ; Character set of the return URL
 N PARSED ; Parsed array which stores each line on a separate node.
 D PARSE10^%ydbwebutils(.BODY,.PARSED) ; Parser
 N DIE,XCN S DIE="PARSED(",XCN=0 D SAVE(ARGS("routine"))
 Q "/r/"_ARGS("routine")
 ;
SAVE(RN) ; [Private] Save a routine
 Q:$E(RN,1,4)'="KBAN"  ; Just for this server, don't do this.
 N %,%F,%I,%N,SP,$ETRAP
 S $ETRAP="S $ECODE="""" Q"
 S %I=$I,SP=" ",%F=$P($$SRCDIR^%RSEL," ")_"/"_$TR(RN,"%","_")_".m"
 O %F:newversion U %F
 F  S XCN=$O(@(DIE_XCN_")")) Q:XCN'>0  S %=@(DIE_XCN_")") Q:$E(%,1)="$"  I $E(%)'=";" W %,!
 C %F ;S %N=$$NULL
 ZLINK RN
 ;C %N
 U %I
 Q
 ;
err(RESULT,ARGS) ; GET /test/error Force M Error
 I $G(ARGS("foo"))="crash2" S %webcrash2=1 ; crash the error trap
 D err1
 QUIT
err1 ;
 N X S X=1/0
 ;
bigoutput(result,args) ; GET /test/bigoutput - Used by Unit Tests to ensure large output is handled appropriately
 n a,b,c
 s $p(a,"a",2**10)="a"
 n i for i=1:1:32 s result(i)=a
 s result(32)=$e(result(32),1,$l(result(32))-1)
 s b=$c(13,10)
 s result(33)=b
 s result("mime")="text/plain; charset=utf-8" ; type of data to send browser
 quit
 ;
gloreturn(result,args) ; GET /test/gloreturn - Used by Unit Tests to ensure Global deleted properly
 s result=$name(^web("%ydbwebapi"))
 s @result="coo"_$c(13,10)
 s @result@(1)="boo"_$c(13,10)
 s @result@(2)="foo"_$c(13,10)
 s result("mime")="text/plain; charset=utf-8" ; type of data to send browser
 quit
 ;
utf8get(res,params) ; /test/utf8/get
 set res=params("foo")
 set res("mime")="text/plain; charset=UTF-8"
 quit
 ;
utf8post(params,body,res) ; /test/utf8/post
 new output
 do decode^%ydbwebjson($na(body),$na(output))
 set res(1)=$extract(params("foo"),1,3)_$C(13,10)
 set res(2)=$get(output("直接"))
 quit "test/utf8/post?foo="_params("foo")
 ;
ping(RESULT,ARGS) ; writes out a ping response
 S RESULT="{""self"": """_$J_""", ""server"": """_PPID_"""}"
 Q
xml(RESULT,ARGS) ; text XML
 S HTTPRSP("mime")="text/xml"
 S RESULT(1)="<?xml version=""1.0"" encoding=""UTF-8""?>"
 S RESULT(2)="<note>"
 S RESULT(3)="<to>Tovaniannnn</to>"
 S RESULT(4)="<from>Jani</from>"
 S RESULT(5)="<heading>Reminders</heading>"
 S RESULT(6)="<body>Don't forget me this weekend!</body>"
 S RESULT(7)="</note>"
 QUIT
 ;
customerr(r,a) ; custom error
 n errarr
 s errarr("resourceType")="OperationOutcome"
 s errarr("issue",1,"severity")="error"
 s errarr("issue",1,"code")="processing"
 s errarr("issue",1,"diagnostics")="Test message"
 d customError^%ydbwebutils(400,.errarr)
 quit
 ;
empty(r,a) ; Empty. Used For Unit Tests
 s r=""
 QUIT
 ;
posttest(ARGS,BODY,RESULT) ; Simple test for post, handles /test/post
 N PARAMS ; Parsed array which stores each line on a separate node.
 D decode^%ydbwebjson($NA(BODY),$NA(PARAMS),$NA(%WERR))
 I $D(%WERR) D SETERROR^%ydbwebutils("400","Input parameters not correct") QUIT ""
 ;
 S RESULT("mime")="text/plain; charset=utf-8" ; Character set of the return URL
 S RESULT="/path/"_PARAMS("random")_"/1" ; Stored URL
 Q RESULT

FILESYS(RESULT,ARGS) ; Handle filesystem/*
 I '$D(ARGS)&$D(PATHSEG) S ARGS("*")=PATHSEG
 N PATH
 ;
 ; Ok, get the actual path
 S PATH=$ZDIRECTORY_ARGS("*")
 ;
 ; GT.M errors out on FNF; Need timeout and else.
 N $ET S $ET="G FILESYSE"
 ;
 ; Fixed prevents Reads to terminators on SD's. CHSET makes sure we don't analyze UTF.
 O PATH:(REWIND:READONLY:FIXED:CHSET="M")
 ;
 ; Set content-cache value; defaults to one week.
 set RESULT("cache")=604800
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
 set MIMELKUP("css")="text/css"
 set MIMELKUP("csv")="text/csv"
 set MIMELKUP("doc")="application/msword"
 set MIMELKUP("gif")="image/gif"
 set MIMELKUP("htm")="text/html"
 set MIMELKUP("html")="text/html"
 set MIMELKUP("ico")="image/x-icon"
 set MIMELKUP("jpe")="image/jpeg"
 set MIMELKUP("jpeg")="image/jpeg"
 set MIMELKUP("jpg")="image/jpeg"
 set MIMELKUP("js")="application/javascript"
 set MIMELKUP("kid")="text/x-mumps-kid"
 set MIMELKUP("m")="text/x-mumps"
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
 set MIMELKUP("txt")="text/plain"
 set MIMELKUP("log")="text/plain"
 set MIMELKUP("wav")="audio/wav"
 set MIMELKUP("xls")="application/vnd.ms-excel"
 set MIMELKUP("zip")="application/zip"
 set MIMELKUP("woff")="font/woff"
 set MIMELKUP("woff2")="font/woff2"
 set MIMELKUP("ttf")="font/ttf"
 set MIMELKUP("eot")="font/eot"
 set MIMELKUP("otf")="font/otf"
 new EXT set EXT=$PIECE(PATH,".",$LENGTH(PATH,"."))
 if $DATA(MIMELKUP(EXT)) set RESULT("mime")=MIMELKUP(EXT)
 else  set RESULT("mime")=MIMELKUP("txt")
 ;
 ; Read operation
 U PATH
 N C S C=1
 N X F  R X#4079:0 S RESULT(C)=X,C=C+1 Q:$ZEOF
 C PATH
 QUIT
 ;
FILESYSE ; 500
 S $EC=""
 D setError^%ydbwebutils("500",$ZS)
 QUIT
 ;
 ; Copyright (c) 2013-2020 Sam Habiel
 ; Copyright (c) 2018 Kenneth McLoghlen
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
