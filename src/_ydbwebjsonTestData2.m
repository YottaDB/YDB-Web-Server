%ydbwebjsonTestData2 ;SLC/KCM -- Sample data for JSON encoding;Feb 07, 2019@10:58
	;
	;
	; Portions of this code are public domain, but it was extensively modified
	; Copyright 2016 Accenture Federal Services
	; Copyright 2013-2019 Sam Habiel
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
	; expected return data values
	;
basic ;; Basic object
	;;{"myObj":{"array":["one","two","three"],"booleanF":false,"booleanT":true,"nullValue":null,"numeric":3.1416,"subObject":{"fieldA":"hello","fieldB":"world"}}}
vals ;; Simple values only object
	;;{"arr":["apple","orange","pear",{"obj":"4th array item is object"}],"bool1":true,"num1":2.1e3,"prop1":"property1"}
long ;; Object with continuation nodes
	;;{"note":"This is the first line of the note.  Here are \"quotes\" and a \\ and a \/.\nAdditional Line #1, this will extend the line out to at least 78 characters.\nAdditional Line #2,
nodes ;; Nodes preformatted as JSON
	;;{"value": "New", "onclick": "CreateNewDoc()"}
	;;{"value": "Open", "onclick": "OpenDoc()"}
	;;{"value": "Close", "onclick": "CloseDoc()"}
	;;{"data":"Click Here","size":36,"style":"bold","name":"text1","hOffset":250,"vOffset":100,"alignment":"center","onMouseUp":"sun1.opacity = (sun1.opacity / 100) * 90;"}
pre ;; Adding already encoded values to object
	;;{"count":3,"menu":[{"value": "New", "onclick": "CreateNewDoc()"},{"value": "Open", "onclick": "OpenDoc()"},{"value": "Close", "onclick": "CloseDoc()"}],"template":
	;;{"data":"Click Here","size":36,"style":"bold","name":"text1","hOffset":250,"vOffset":100,"alignment":"center","onMouseUp":"sun1.opacity = (sun1.opacity / 100) * 90;"}}
wpout ;; WP field encoded as JSON
	;;{"dob":"APR 7,1935","gender":"MALE","lastVitals":{"height":{"lastDone":"Aug 24, 2009","value":190},"weight":{"lastDone":"Jul 01, 2011","value":210}},"name":"AVIVAPATIENT,THIRTY","patDemDetails":{"text":"               COORDINATING
	;; MASTER OF RECORD: ABILENE (CAA)\r\n Address: Any Street                    Temporary: NO TEMPORARY ADDRESS\r\n         Any Town,WV 99998-0071\r\n         \r\n  County: UNSPECIFIED                     From\/To: NOT APPLICABLE\r\n"},
	;;"uid":"urn:va:F484:8:patient:8"}
ltzero ;; Leading and trailing zeros
	;;{"code":".77","count":737,"errors":0,"icd":"626.00","price":0.65,"ssn":"000427930"}
strings ;; strings that look like numbers
	;;{"count":234567,"hl7Time":"20120919","icd":"722.10","name":"Duck,Donald"}
ex1out ;; JSON.org example #1 target
	;;{"menu":{"id":"file","popup":{"menuitem":[{"onclick":"CreateNewDoc()","value":"New"},{"onclick":"OpenDoc()","value":"Open"},{"onclick":"CloseDoc()","value":"Close"}]},"value":"File"}}
ex2out ;; JSON.org example #2 target
	;;{"glossary":{"GlossDiv":{"GlossList":{"GlossEntry":{"Abbrev":"ISO 8879:1986","Acronym":"SGML","GlossDef":{"GlossSeeAlso":["GML","XML"],"para":"A meta-markup language, used to create markup languages such as DocBook."}
	;;,"GlossSee":"markup","GlossTerm":"Standard Generalized Markup Language","ID":"SGML","SortAs":"SGML"}},"title":"S"},"title":"example glossary"}}
ex3out ;; JSON.org example #3 target
	;;{"widget":{"debug":"on","image":{"alignment":"center","hOffset":250,"name":"sun1","src":"Images\/Sun.png","vOffset":250},"text":{"alignment":"center","data":"Click Here","hOffset":250,"name":"text1","onMouseUp":
	;;"sun1.opacity = (sun1.opacity \/ 100) * 90;","size":36,"style":"bold","vOffset":100},"window":{"height":500,"name":"main_window","title":"Sample Konfabulator Widget","width":500}}}
ex4out ;; JSON.org example #4 target
	;;{"web-app":{"servlet":[{"init-param":{"cachePackageTagsRefresh":60,"cachePackageTagsStore":200,"cachePackageTagsTrack":200,"cachePagesDirtyRead":10,"cachePagesRefresh":10,"cachePagesStore":100,"cachePagesTrack":200,
	;
	; data values to test long text field input
	;
wp ;; object with word processing field
	;;y("dob")="APR 7,1935"
	;;y("gender")="MALE"
	;;y("lastVitals","height","lastDone")="Aug 24, 2009"
	;;y("lastVitals","height","value")=190
	;;y("lastVitals","weight","lastDone")="Jul 01, 2011"
	;;y("lastVitals","weight","value")=210
	;;y("name")="AVIVAPATIENT,THIRTY"
	;;y("patDemDetails","text","\",6)="               COORDINATING MASTER OF RECORD: ABILENE (CAA)"_$char(13,10)
	;;y("patDemDetails","text","\",7)=" Address: Any Street                    Temporary: NO TEMPORARY ADDRESS"_$char(13,10)
	;;y("patDemDetails","text","\",8)="         Any Town,WV 99998-0071"_$char(13,10)
	;;y("patDemDetails","text","\",9)="         "_$char(13,10)
	;;y("patDemDetails","text","\",10)="  County: UNSPECIFIED                     From/To: NOT APPLICABLE"_$char(13,10)
	;;y("uid")="urn:va:F484:8:patient:8"
	;;zzzzz
	;
	; data values for JSON.ORG examples rendered as M arrays
	;
ex1in ;; JSON.org example #1
	;;y("menu","id")="file"
	;;y("menu","popup","menuitem",1,"onclick")="CreateNewDoc()"
	;;y("menu","popup","menuitem",1,"value")="New"
	;;y("menu","popup","menuitem",2,"onclick")="OpenDoc()"
	;;y("menu","popup","menuitem",2,"value")="Open"
	;;y("menu","popup","menuitem",3,"onclick")="CloseDoc()"
	;;y("menu","popup","menuitem",3,"value")="Close"
	;;y("menu","value")="File"
	;;zzzzz
ex2in ;; JSON.org example #2
	;;y("glossary","GlossDiv","GlossList","GlossEntry","Abbrev")="ISO 8879:1986"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","Acronym")="SGML"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","GlossDef","GlossSeeAlso",1)="GML"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","GlossDef","GlossSeeAlso",2)="XML"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","GlossDef","para")="A meta-markup language, used to create markup languages such as DocBook."
	;;y("glossary","GlossDiv","GlossList","GlossEntry","GlossSee")="markup"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","GlossTerm")="Standard Generalized Markup Language"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","ID")="SGML"
	;;y("glossary","GlossDiv","GlossList","GlossEntry","SortAs")="SGML"
	;;y("glossary","GlossDiv","title")="S"
	;;y("glossary","title")="example glossary"
	;;zzzzz
ex3in ;; JSON.org example #3
	;;y("widget","debug")="on"
	;;y("widget","image","alignment")="center"
	;;y("widget","image","hOffset")=250
	;;y("widget","image","name")="sun1"
	;;y("widget","image","src")="Images/Sun.png"
	;;y("widget","image","vOffset")=250
	;;y("widget","text","alignment")="center"
	;;y("widget","text","data")="Click Here"
	;;y("widget","text","hOffset")=250
	;;y("widget","text","name")="text1"
	;;y("widget","text","onMouseUp")="sun1.opacity = (sun1.opacity / 100) * 90;"
	;;y("widget","text","size")=36
	;;y("widget","text","style")="bold"
	;;y("widget","text","vOffset")=100
	;;y("widget","window","height")=500
	;;y("widget","window","name")="main_window"
	;;y("widget","window","title")="Sample Konfabulator Widget"
	;;y("widget","window","width")=500
	;;zzzzz
ex4in ;; JSON.org example #4
	;;y("web-app","servlet",1,"init-param","cachePackageTagsRefresh")=60
	;;y("web-app","servlet",1,"init-param","cachePackageTagsStore")=200
	;;y("web-app","servlet",1,"init-param","cachePackageTagsTrack")=200
	;;y("web-app","servlet",1,"init-param","cachePagesDirtyRead")=10
	;;y("web-app","servlet",1,"init-param","cachePagesRefresh")=10
	;;y("web-app","servlet",1,"init-param","cachePagesStore")=100
	;;y("web-app","servlet",1,"init-param","cachePagesTrack")=200
	;;y("web-app","servlet",1,"init-param","cacheTemplatesRefresh")=15
	;;y("web-app","servlet",1,"init-param","cacheTemplatesStore")=50
	;;y("web-app","servlet",1,"init-param","cacheTemplatesTrack")=100
	;;y("web-app","servlet",1,"init-param","configGlossary:adminEmail")="ksm@pobox.com"
	;;y("web-app","servlet",1,"init-param","configGlossary:installationAt")="Philadelphia, PA"
	;;y("web-app","servlet",1,"init-param","configGlossary:poweredBy")="Cofax"
	;;y("web-app","servlet",1,"init-param","configGlossary:poweredByIcon")="/images/cofax.gif"
	;;y("web-app","servlet",1,"init-param","configGlossary:staticPath")="/content/static"
	;;y("web-app","servlet",1,"init-param","dataStoreClass")="org.cofax.SqlDataStore"
	;;y("web-app","servlet",1,"init-param","dataStoreConnUsageLimit")=100
	;;y("web-app","servlet",1,"init-param","dataStoreDriver")="com.microsoft.jdbc.sqlserver.SQLServerDriver"
	;;y("web-app","servlet",1,"init-param","dataStoreInitConns")=10
	;;y("web-app","servlet",1,"init-param","dataStoreLogFile")="/usr/local/tomcat/logs/datastore.log"
	;;y("web-app","servlet",1,"init-param","dataStoreLogLevel")="debug"
	;;y("web-app","servlet",1,"init-param","dataStoreMaxConns")=100
	;;y("web-app","servlet",1,"init-param","dataStoreName")="cofax"
	;;y("web-app","servlet",1,"init-param","dataStorePassword")="dataStoreTestQuery"
	;;y("web-app","servlet",1,"init-param","dataStoreTestQuery")="SET NOCOUNT ON;select test='test';"
	;;y("web-app","servlet",1,"init-param","dataStoreUrl")="jdbc:microsoft:sqlserver://LOCALHOST:1433;DatabaseName=goon"
	;;y("web-app","servlet",1,"init-param","dataStoreUser")="sa"
	;;y("web-app","servlet",1,"init-param","defaultFileTemplate")="articleTemplate.htm"
	;;y("web-app","servlet",1,"init-param","defaultListTemplate")="listTemplate.htm"
	;;y("web-app","servlet",1,"init-param","jspFileTemplate")="articleTemplate.jsp"
	;;y("web-app","servlet",1,"init-param","jspListTemplate")="listTemplate.jsp"
	;;y("web-app","servlet",1,"init-param","maxUrlLength")=500
	;;y("web-app","servlet",1,"init-param","redirectionClass")="org.cofax.SqlRedirection"
	;;y("web-app","servlet",1,"init-param","searchEngineFileTemplate")="forSearchEngines.htm"
	;;y("web-app","servlet",1,"init-param","searchEngineListTemplate")="forSearchEnginesList.htm"
	;;y("web-app","servlet",1,"init-param","searchEngineRobotsDb")="WEB-INF/robots.db"
	;;y("web-app","servlet",1,"init-param","templateLoaderClass")="org.cofax.FilesTemplateLoader"
	;;y("web-app","servlet",1,"init-param","templateOverridePath")=""
	;;y("web-app","servlet",1,"init-param","templatePath")="templates"
	;;y("web-app","servlet",1,"init-param","templateProcessorClass")="org.cofax.WysiwygTemplate"
	;;y("web-app","servlet",1,"init-param","useDataStore")="true"
	;;y("web-app","servlet",1,"init-param","useJSP")="false"
	;;y("web-app","servlet",1,"servlet-class")="org.cofax.cds.CDSServlet"
	;;y("web-app","servlet",1,"servlet-name")="cofaxCDS"
	;;y("web-app","servlet",2,"init-param","mailHost")="mail1"
	;;y("web-app","servlet",2,"init-param","mailHostOverride")="mail2"
	;;y("web-app","servlet",2,"servlet-class")="org.cofax.cds.EmailServlet"
	;;y("web-app","servlet",2,"servlet-name")="cofaxEmail"
	;;y("web-app","servlet",3,"servlet-class")="org.cofax.cds.AdminServlet"
	;;y("web-app","servlet",3,"servlet-name")="cofaxAdmin"
	;;y("web-app","servlet",4,"servlet-class")="org.cofax.cds.FileServlet"
	;;y("web-app","servlet",4,"servlet-name")="fileServlet"
	;;y("web-app","servlet",5,"init-param","adminGroupID")=4
	;;y("web-app","servlet",5,"init-param","betaServer")="true"
	;;y("web-app","servlet",5,"init-param","dataLog")=1
	;;y("web-app","servlet",5,"init-param","dataLogLocation")="/usr/local/tomcat/logs/dataLog.log"
	;;y("web-app","servlet",5,"init-param","dataLogMaxSize")=""
	;;y("web-app","servlet",5,"init-param","fileTransferFolder")="/usr/local/tomcat/webapps/content/fileTransferFolder"
	;;y("web-app","servlet",5,"init-param","log")=1
	;;y("web-app","servlet",5,"init-param","logLocation")="/usr/local/tomcat/logs/CofaxTools.log"
	;;y("web-app","servlet",5,"init-param","logMaxSize")=""
	;;y("web-app","servlet",5,"init-param","lookInContext")=1
	;;y("web-app","servlet",5,"init-param","removePageCache")="/content/admin/remove?cache=pages&id="
	;;y("web-app","servlet",5,"init-param","removeTemplateCache")="/content/admin/remove?cache=templates&id="
	;;y("web-app","servlet",5,"init-param","templatePath")="toolstemplates/"
	;;y("web-app","servlet",5,"servlet-class")="org.cofax.cms.CofaxToolsServlet"
	;;y("web-app","servlet",5,"servlet-name")="cofaxTools"
	;;y("web-app","servlet-mapping","cofaxAdmin")="/admin/*"
	;;y("web-app","servlet-mapping","cofaxCDS")="/"
	;;y("web-app","servlet-mapping","cofaxEmail")="/cofaxutil/aemail/*"
	;;y("web-app","servlet-mapping","cofaxTools")="/tools/*"
	;;y("web-app","servlet-mapping","fileServlet")="/static/*"
	;;y("web-app","taglib","taglib-location")="/WEB-INF/tlds/cofax.tld"
	;;y("web-app","taglib","taglib-uri")="cofax.tld"
	;;zzzzz

