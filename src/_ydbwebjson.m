%ydbwebjson ;SLC/KCM -- Decode/Encode JSON;2019-07-16  2:17 PM
	;
	; Note:  Since the routines use closed array references, %ydbroot and %ydberr
	;        are used to reduce risk of naming conflicts on the closed array.
	;
	; Set JSON object into closed array ref %ydbroot
	; Examples: do decode^%ydbwebjson("MYJSON","LOCALVAR","LOCALERR")
	;           do decode^%ydbwebjson("^MYJSON(1)","^GLO(99)","^TMP($J)")
	;
	; %ydbjson: string/array containing serialized JSON object
	; %ydbroot: closed array reference for M representation of object
	;  %ydberr: contains error messages, defaults to ^TMP("%ydbwebjsonerr",$J)
	;
decode(%ydbjson,%ydbroot,%ydberr) goto direct^%ydbwebjsonDecode
	;
	; Examples:  do encode^%ydbwebjson("^GLO(99,2)","^TMP($J)")
	;            do encode^%ydbwebjson("LOCALVAR","MYJSON","LOCALERR")
	;
	; %ydbroot: closed array reference for M representation of object
	; %ydbjson: destination variable for the string array formatted as JSON
	;  %ydberr: contains error messages, defaults to ^TMP("%ydbwebjsonerr",$J)
	;
encode(%ydbroot,%ydbjson,%ydberr) goto direct^%ydbwebjsonEncode
	;
	;
esc(x) quit $$esc^%ydbwebjsonEncode(x) ; Escape string for JSON
ues(x) quit $$ues^%ydbwebjsonDecode(x) ; Unescape JSON string
	;
errx(id,val) ; Set the appropriate error message
	; switch (id) -- xerrx ends statement
	N errmsg
	;
	; Decode Error Messages
	;
	if id="STL{" set errmsg="Stack too large for new object." goto xerrx
	if id="SUF}" set errmsg="Stack Underflow - extra } found" goto xerrx
	if id="STL[" set errmsg="Stack too large for new array." goto xerrx
	if id="SUF]" set errmsg="Stack Underflow - extra ] found." goto xerrx
	if id="OBM" set errmsg="Array mismatch - expected ] got }." goto xerrx
	if id="ARM" set errmsg="Object mismatch - expected } got ]." goto xerrx
	if id="MPN" set errmsg="Missing property name." goto xerrx
	if id="EXT" set errmsg="Expected true, got "_val goto xerrx
	if id="EXF" set errmsg="Expected false, got "_val goto xerrx
	if id="EXN" set errmsg="Expected null, got "_val goto xerrx
	if id="TKN" set errmsg="Unable to identify type of token, value was "_val goto xerrx
	if id="SCT" set errmsg="Stack mismatch - exit stack level was  "_val goto xerrx
	if id="EIQ" set errmsg="Close quote not found before end of input." goto xerrx
	if id="EIU" set errmsg="Unexpected end of input while unescaping." goto xerrx
	if id="RSB" set errmsg="Reverse search for \ past beginning of input." goto xerrx
	if id="ORN" set errmsg="Overrun while scanning name." goto xerrx
	if id="OR#" set errmsg="Overrun while scanning number." goto xerrx
	if id="ORB" set errmsg="Overrun while scanning boolean." goto xerrx
	if id="ESC" set errmsg="Escaped character not recognized"_val goto xerrx
	if id="TRL" set errmsg="Trailing characters in JSON object: "_val goto xerrx
	;
	; Encode Error Messages
	;
	if id="SOB" set errmsg="Unable to serialize node as object, value was "_val goto xerrx
	if id="SAR" set errmsg="Unable to serialize node as array, value was "_val goto xerrx
	set errmsg="Unspecified error "_id_" "_$get(val)
xerrx ; end switch
	set @%ydberr@(0)=$get(@%ydberr@(0))+1
	set @%ydberr@(@%ydberr@(0))=errmsg
	set %ydberrors=%ydberrors+1
	quit
	;
	; Most of this code is public domain. New lower case entry points
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
