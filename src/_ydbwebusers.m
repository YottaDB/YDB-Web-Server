%ydbwebusers ; User Management utilities
	;
	quit
	;
createTempDB(ppid) ; [$$] Create a temporary database - returns global directory file path
	; ppid = parent process id
	new tmp set tmp=$$tmp()
	new gld set gld=tmp_"/ydbgui"_ppid_".gld"
	new gdefile set gdefile=tmp_"/ydbgui"_ppid_".gde"
	new dbfile  set dbfile=tmp_"/ydbgui"_ppid_".dat"
	;
	; If it doesn't exist, create it
	; Create a temporary database
	if $zsearch(gld,-1)="" do
	. open gdefile:newversion
	. use gdefile
	. write "change -segment DEFAULT -file="""_dbfile_"""",!
	. write "exit",!
	. close gdefile
	. open "pipe":(shell="/bin/bash":command="ydb_gbldir="""_gld_""" $ydb_dist/yottadb -r GDE @"_gdefile)::"pipe"
	. use "pipe"
	. new x for i=1:1 read x(i) quit:$zeof
	. close "pipe"
	. if $zclose'=0 write "An error occurred... Contact YottaDB Support.",! zwrite x
	. ;
	. open gdefile
	. close gdefile:delete
	. ;
	. open "pipe":(shell="/bin/bash":command="ydb_gbldir="""_gld_""" $ydb_dist/mupip create")::"pipe"
	. use "pipe"
	. new x for i=1:1 read x(i) quit:$zeof
	. close "pipe"
	. if $zclose'=0 write "An error occurred... Contact YottaDB Support.",! zwrite x 
	do:httplog>0 stdout^%ydbwebutils("Created tokens database - global directory: "_gld)
	do:httplog>0 stdout^%ydbwebutils("                        - database file   : "_dbfile)
	quit gld
	;
deletedb(ppid,silent) ; [Private] Delete database files
	; ppid = parent process id
	; silent (optional) = don't write
	set silent=$get(silent)
	if 'silent use $principal write "Deleting tokens database files (if present)",!
	new tmp set tmp=$$tmp()
	open tmp_"/ydbgui"_ppid_".dat":(readonly:exception="goto deletedb1")
	close tmp_"/ydbgui"_ppid_".dat":delete
deletedb1 ; goto target
	open tmp_"/ydbgui"_ppid_".gld":(readonly:exception="goto deletedb2")
	close tmp_"/ydbgui"_ppid_".gld":delete
deletedb2 ; goto target
	quit
	;
tmp() ; [$$ Private] Get temporary directory
	if $ztrnlnm("ydb_tmp")'="" quit $ztrnlnm("ydb_tmp")
	else  quit "/tmp"
	quit ""
	;
	;
stdin ; Supply Usernames/Password/Authorization on stdin
	write !
	write "Please enter usernames, passwords, authorization at the prompts:",!
	write "Enter enter without entering a username to quit from the loop.",!
	new done set done=0
	new users,userCount
	for  do  quit:done
	. new username,password,authorization
	. read !,"Username: ",username  if (username="")!(username="^") write ! set done=1 quit
	. for  use 0:noecho read !,"Password: ",password use 0:echo quit:password'=""  write ?35,"Must enter a value"
	. for  read !,"Authorization: ",authorization  quit:authorization'=""  write ?35,"Must enter a value"
	. write !
	. if $increment(userCount)
	. set users(userCount,"username")=username
	. set users(userCount,"password")=$$passwordHash(password)
	. set users(userCount,"authorization")=authorization
	. do setusers(users(userCount,"username"),users(userCount,"password"),users(userCount,"authorization"))
	write "Saving users to file users.json with passwords hashed",!
	do saveUsersBack("users.json",.users)
	quit
	;
file(file) ; [$$] Read file for usernames and passwords
	          ; 0 = success; 1 = failure
	          ; Hash the passwords if need be
	new x,i
	new $etrap,$estack set $etrap="goto fileErr"
	open file:readonly use file
	for i=1:1 read x(i) quit:$zeof
	use $principal close file
	set $etrap="goto otherErr"
	;
	; Decode x from JSON to an M array
	new users,jsonerror
	do decode^%ydbwebjson($name(x),$name(users),$name(jsonerror))
	new error set error=0
	if $data(jsonerror)                 set error=1
	if '$data(users(1,"username"))      set error=1
	if '$data(users(1,"password"))      set error=1
	if '$data(users(1,"authorization")) set error=1
	;
	if error write "User file is not a valid JSON file",! quit error
	;
	; Check if any of the passwords needs to be hashed
	new passwordsGotHashed set passwordsGotHashed=0
	for i=0:0 set i=$order(users(i)) quit:'i  if $extract(users(i,"password"))'="$" do
	. write "Hashing password for user "_users(i,"username"),!
	. set users(i,"password")=$$passwordHash(users(i,"password"))
	. set passwordsGotHashed=1
	;
	; Write back the file if passwords got hashed
	if passwordsGotHashed do saveUsersBack(file,.users)
	;
	for i=0:0 set i=$order(users(i)) quit:'i  do setusers(users(i,"username"),users(i,"password"),users(i,"authorization"))
	quit 0
	;
saveUsersBack(file,users)
	new usersencoded
	do encode^%ydbwebjson($name(users),$name(usersencoded))
	open file:newversion use file
	new tabs set tabs=0
	new i,j,c,inquotes
	set inquotes=0
	for i=0:0 set i=$order(usersencoded(i)) quit:'i  do
	. for j=1:1:$length(usersencoded(i)) set c=$extract(usersencoded(i),j) do
	.. if "{["[c write ?(tabs*8),c,! set tabs=tabs+1 write ?(tabs*8) quit
	.. if "}]"[c write ! set tabs=tabs-1 write ?(tabs*8),c quit
	.. if c=":" write c," " quit
	.. if c="""" set inquotes='inquotes write c quit
	.. if c=",",'inquotes write c,!,?(tabs*8) quit
	.. write c
	close file
	quit
	;
fileErr
	quit:$estack
	set $ecode=""
	use $principal
	write "File "_file_" does not exist or RW permissions are not available",!
	quit 1
	;
otherErr
	quit:$estack
	set $ecode=""
	use $principal
	write "Error: ",$ZSTATUS,!
	quit 1
	;
passwordHash(password)
	new x set x=$&sodium.pwhash(password)
	if x="" write "Error: ",$ZSTATUS,! set $ecode=",U999,"
	quit x
	;
setusers(username,passwordHash,authorization)
	tstart ():transactionid="batch"
	  set ^|httpwebgld|users(username,"hash")=passwordHash
	  set ^|httpwebgld|users(username,"auth")=authorization
	tcommit
	quit
	;
getAuthorizationFromUser(username)
	quit ^|httpwebgld|users(username,"auth")
	;
checkIfUserExists(username,password)
	new storedPasswordHash set storedPasswordHash=$get(^|httpwebgld|users(username,"hash"))
	if storedPasswordHash="" quit 0
	new result set result=$$verifypasswordHash(password,storedPasswordHash)
	if result=0 quit 1  ; valid password
	if result=-1 quit 0 ; Invalid password
	set $ecode=",U999," ; Invalid fallthrough
	quit ""
	;
verifypasswordHash(password,passwordHash)
	new result set result=$&sodium.pwverify(password,passwordHash)
	if result=-99 write "Error: ",$ZSTATUS,! set $ecode=",U999,"
	quit result
	;
generateToken(username)
	new randomString set randomString=$&sodium.randombuf(32)
	if randomString="" write "Error: ",$ZSTATUS,! set $ecode=",U999,"
	quit $zysuffix(randomString_username)
	;
storeToken(token,authorization)
	tstart ():transactionid="batch"
	  new time set time=$ZUT
	  set ^|httpwebgld|tokensByTime(time,token)=""
	  set ^|httpwebgld|tokens(token)=time_"^"_authorization
	tcommit
	quit
	;
checkIfTokenExists(token)
	quit ''$data(^|httpwebgld|tokens(token))
	;
checkIfTokenIsExpired(token)
	if httpttimeout=0 quit 0 ; no timeout
	new currentZUT set currentZUT=$ZUT
	new tokenZUT   set tokenZUT=$zpiece(^|httpwebgld|tokens(token),"^",1)
	new zutdiff    set zutdiff=currentZUT-tokenZUT
	if zutdiff>httpttimeout quit 1 
	quit 0
	; 
updateTokenTimeout(token)
	new oldtime set oldtime=$zpiece(^|httpwebgld|tokens(token),"^",1)
	new newtime set newtime=$ZUT
	tstart ():transactionid="batch"
	  set $zpiece(^|httpwebgld|tokens(token),"^",1)=newtime
	  kill ^|httpwebgld|tokensByTime(oldtime,token)
	  set ^|httpwebgld|tokensByTime(newtime,token)=""
	tcommit
	quit
	;
getAuthorizationFromToken(token)
	quit $zpiece(^|httpwebgld|tokens(token),"^",2)
	;
deleteToken(token)
	new oldtime set oldtime=$zpiece(^|httpwebgld|tokens(token),"^",1)
	tstart ():transactionid="batch"
	  kill ^|httpwebgld|tokensByTime(oldtime,token)
	  kill ^|httpwebgld|tokens(token)
	tcommit
	quit
	;
tokenCleanup
	if httpttimeout=0 quit  ; no timeout
	; cutoffZUT is in the past (that's why it's a minus from now, not a plus)
	new currentZUT set currentZUT=$ZUT
	new cutoffZUT  set cutoffZUT=currentZUT-(httpttimeout*10) ; Don't delete tokens up to 10 times the timeout
	;
	; Set iterator to start from the cutoff time
	new zutIter set zutIter=cutoffZUT
	;
	; Loop from cutoff time to times that are smaller (older) in the past.
	for  set zutIter=$order(^|httpwebgld|tokensByTime(zutIter),-1) quit:zutIter=""  do
	. new eachToken set eachToken=""
	. tstart ():transactionid="batch"
	.   for  set eachToken=$order(^|httpwebgld|tokensByTime(zutIter,eachToken)) quit:eachToken=""  kill ^|httpwebgld|tokens(eachToken)
	.   kill ^|httpwebgld|tokensByTime(zutIter)
	. tcommit
	quit
	;
	;
	; Copyright (c) 2023-2024 YottaDB LLC
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
