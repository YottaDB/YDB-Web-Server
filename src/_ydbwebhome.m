%ydbwebhome ; VEN/SMH - Home page processor;jun 20, 2022@15:59
	;;
	; Copyright (c) 2013-2019 Sam Habiel
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
	;
en(result) ; PEP
	set result("mime")="text/html; charset=utf-8"
	new crlf set crlf=$char(13,10)
	new path set path="index.html"
	; Retrieve index.html from filesystem before returning default page
	do filesys^%ydbwebapi(path)
	; If we have an error, it means we don't have an index page; ignore and return handlers page instead
	if httperr set httperr=0 kill result
	; If we found an index.html don't return the default
	if $data(result) quit
	;
	set result("mime")="text/html; charset=utf-8"
	; return default index.html
	new i for i=1:1 set result(i)=$zpiece($text(html+i),";;",2,99) quit:result(i)=""  D
	. if result(i)["<%TABLEDATA%>" D
	.. if $text(^%ydbweburl)="" set result(i)="<strong>No web request handlers installed.</strong>"
	.. new line
	.. new j set j=i ; Replace "<%TABLEDATA%>"
	.. for seq=1:1 set line=$zpiece($text(URLMAP+seq^%ydbweburl),";;",2,99) quit:line=""  quit:line="zzzzz"  D
	... new method,url,rtn,ep
	... set method=$zpiece(line," ",1)
	... set url=$zpiece(line," ",2)
	... set ep=$zpiece(line," ",3)
	... set rtn=$zpiece(ep,"^",2),rtn=$$urlenc^%ydbwebutils(rtn)
	... ;
	... set result(j)="<tr>",j=j+.0001
	... set result(j)="<td>"_method_"</td>",j=j+.0001
	... set result(j)="<td>"_url_"</td>",j=j+.0001
	... set result(j)="<td><a href=""test/r/"_rtn_""">"_ep_"</td>",j=j+.0001
	... set result(j)="</tr>",j=j+.0001
	. if result(i)="<%FOOTER%>" set result(i)="$JOB="_$job_" | $SYSTEM="_$system
	. set result(i)=result(i)_crlf
	kill result(i) ; Kill last one which is empty.
	quit
	;
html ; HTML to Write out
	;;<!doctype html>
	;;<html>
	;;<head>
	;;<title>YottaDB Restful Web-Services Portal</title>
	;;<style>
	;; body {
	;;     margin: 0 0 0 0;
	;;     font-family: "Helvetica Neue",Helvetica,Arial,sans-serif;
	;;     font-size: 14px;
	;;     line-height: 1.428571429;
	;;     background-color: rgb(245, 217, 181)
	;; }
	;; header {
	;;     background-color: rgb(92, 81, 37);
	;;     box-sizing: border-box;
	;;     color: rgb(253, 252, 245);
	;;     text-align: center;
	;;     vertical-align: middle;
	;;     padding-top: 1.2em;
	;;     padding-bottom: 0.5em;
	;;     position: fixed;
	;;     top: 0;
	;;     right: 0;
	;;     left: 0;
	;;     }
	;; header > span {
	;;     font-size: 3em;
	;;     line-height: 1em;
	;; }
	;; footer {
	;;     background-color: black;
	;;     box-sizing: border-box;
	;;     color: white;
	;;     #position: fixed;
	;;     #bottom: 0;
	;;     width: 100%;
	;;     text-align: center;
	;;     }
	;; main {
	;;     box-sizing: border-box;
	;;     display: block;
	;;     font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
	;;     padding-bottom: 140px;
	;;     padding-left: 15px;
	;;     padding-right: 15px;
	;;     padding-top: 140px;
	;;     text-align: left;
	;;     text-shadow: rgba(0, 0, 0, 0.14902) 0px 1px 0px;
	;; }
	;; table, td, tr, th {
	;;     border: 1px solid black;
	;;     border-collapse:collapse;
	;;     padding: 15px;
	;; }
	;;</style>
	;;</head>
	;;<body>
	;;<header>
	;; <span>YottaDB Restful Web-Services Portal</span>
	;;</header>
	;;<main>
	;;<p>
	;; Welcome to the YottaDB Web Services.
	;;</p>
	;;<p>
	;; Here is a list of web services configured on this server.
	;; <table>
	;;  <tr>
	;;   <th>HTTP VERB</th>
	;;   <th>URI</th>
	;;   <th>Execution Endpoint</th>
	;;  </tr>
	;;    <%TABLEDATA%>
	;; </table>
	;;</p>
	;;</main>
	;;<footer>
	;;<span>
	;;<%FOOTER%>
	;;</span>
	;;</footer>
	;;</body>
	;;</html>

