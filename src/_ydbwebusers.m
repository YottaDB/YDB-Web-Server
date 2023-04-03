%ydbwebusers ; User Management utilities
 ;
 quit
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
 . do setcache(username,password,STARTUPZUT)
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
 . do setcache(username,password,STARTUPZUT)
 quit
 ;
token(username,password)
 quit $zysuffix(username_":"_password_":"_STARTUPZUT)
 ;
setcache(username,password,zut)
 new token set token=$$token(username,password)
 ;tstart ():transactionid="batch"
 set TOKENCACHE(token)=zut_"^"_authorization
 set TOKENCACHE("timeindex",zut,token)=""
 ;tcommit
 quit

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
