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
 do:HTTPLOG>0 STDOUT^%ydbwebreq("Created database - global directory: "_gld)
 do:HTTPLOG>0 STDOUT^%ydbwebreq("                 - database file   : "_dbfile)
 quit gld
 ;
deletedb(ppid) ; [Private] Delete database files
 ; ppid = parent process id
 use $principal write "Deleting database files",!
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
 for  do  quit:done
 . new username,password,authorization
 . read !,"Username: ",username  if (username="")!(username="^") set done=1 quit
 . for  read !,"Password: ",password  quit:password'=""  write ?35,"Must enter a value"
 . for  read !,"Authorization (RO, RW): ",authorization  quit:"^RO^RW^"[("^"_authorization_"^")  write ?35,"RO/RW"
 . write !
 . do setusers(username,password,STARTUPZUT)
 quit
 ;
env ; Supply Usernames/Passwords/Authorization in env variable
 new data set data=$ztrnlnm("ydbgui_users")
 new i for i=1:1:$length(data,";") do
 . new datum set datum=$piece(data,";",i)
 . new username   set username=$piece(datum,":",1)
 . new password   set password=$piece(datum,":",2)
 . new authorization set authorization=$piece(datum,":",3)
 . if "^RO^RW^"'[("^"_authorization_"^") quit
 . do setusers(username,password,STARTUPZUT)
 quit
 ;
hash(username,password,salt)
 ; TODO: If we ever get libsodium integration, use the pwhash API from that instead of $zysuffix
 ;       libsodium currently uses Aragon2, and you can also use scrypt
 quit $zysuffix(username_":"_password_":"_salt)
 ;
setusers(username,password,zut)
 new hash set hash=$$hash(username,password,zut)
 set ^|HTTPWEBGLD|users(hash)=authorization
 quit
 ;
getAuthorizationFromUser(userhash)
 quit ^|HTTPWEBGLD|users(userhash)
 ;
checkIfUserExists(userhash) 
 quit ''$data(^|HTTPWEBGLD|users(userhash))
 ;
generateToken(userhash)
 ; TODO: If we ever get libsodium integration, use the PRNG from that instead of /dev/urandom
 new randomString
 new oldio set oldio=$io
 open "/dev/urandom":(readonly:chset="M")
 use "/dev/urandom"
 read randomString#32
 use $io close "/dev/urandom"
 quit $zysuffix(randomString_userhash)
 ;
storeToken(token,authorization)
 tstart ():transactionid="batch"
   new time set time=$ZUT
   set ^|HTTPWEBGLD|tokensByTime(time,token)=""
   set ^|HTTPWEBGLD|tokens(token)=time_"^"_authorization
   tcommit
 quit
 ;
checkIfTokenExists(token)
 quit ''$data(^|HTTPWEBGLD|tokens(token))
 ;
checkIfTokenIsExpired(token)
 if HTTPTTIMEOUT=0 quit 0 ; no timeout
 new currentZUT set currentZUT=$ZUT
 new tokenZUT   set tokenZUT=$piece(^|HTTPWEBGLD|tokens(token),"^")
 new zutdiff    set zutdiff=currentZUT-tokenZUT
 if zutdiff>HTTPTTIMEOUT quit 1 
 quit 0
 ; 
updateTokenTimeout(token)
 new oldtime set oldtime=$piece(^|HTTPWEBGLD|tokens(token),"^",1)
 new newtime set newtime=$ZUT
 tstart ():transactionid="batch"
   set $piece(^|HTTPWEBGLD|tokens(token),"^",1)=newtime
   kill ^|HTTPWEBGLD|tokensByTime(oldtime,token)
   set ^|HTTPWEBGLD|tokensByTime(newtime,token)=""
 tcommit
 quit
 ;
getAuthorizationFromToken(token)
 quit $piece(^|HTTPWEBGLD|tokens(token),"^",2)
 ;
deleteToken(token)
 new oldtime set oldtime=$piece(^|HTTPWEBGLD|tokens(token),"^",1)
 tstart ():transactionid="batch"
   kill ^|HTTPWEBGLD|tokensByTime(oldtime,token)
   kill ^|HTTPWEBGLD|tokens(token)
 tcommit
 quit
 ;
tokenCleanup
 if HTTPTTIMEOUT=0 quit  ; no timeout
 ; cutoffZUT is in the past (that's why it's a minus from now, not a plus)
 new currentZUT set currentZUT=$ZUT
 new cutoffZUT  set cutoffZUT=currentZUT-HTTPTTIMEOUT
 ;
 ; Set iterator to start from the cutoff time
 new zutIter set zutIter=cutoffZUT
 ;
 ; Loop from cutoff time to times that are smaller (older) in the past.
 for  set zutIter=$order(^|HTTPWEBGLD|tokensByTime(zutIter),-1) quit:zutIter=""  do
 . new eachToken set eachToken=""
 . tstart ():transactionid="batch"
 .   for  set eachToken=$order(^|HTTPWEBGLD|tokensByTime(zutIter,eachToken)) quit:eachToken=""  kill ^|HTTPWEBGLD|tokens(eachToken)
 .   kill ^|HTTPWEBGLD|tokensByTime(zutIter)
 . tcommit
 quit
 ;
 ;
 ; Copyright (c) 2023 YottaDB LLC
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
