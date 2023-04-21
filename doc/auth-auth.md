<!--
Copyright (c) 2023 YottaDB LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->
# Authorization and Authentication on the YottaDB Web Server
When you start the server with `start^%ydbwebreq`, nothing in the server will
require any authentication, and all web services can be reached by anybody if
they can reach your network. To protect your web services, enable authentication.

Note that file system pages are NEVER protected by authentication; only web
services defined in your `_ydbweburl` file. This is usually what you want, because
if you can't serve file pages, there is no way to prompt users to log-in.

There are currently two ways to add authentication:

- Start with the `--auth-stdin` flag (recommended), which will prompt you for a
  username, password, and role. You can enter multiple ones if you wish.
- Start with the environment variable `ydbgui_users` set to
  `user:passwd:role(RO/RW);user:passwd:role;...` (not recommended). This is present to assist with
  testing; but shouldn't be used in production, as it leaves the information
  visible in the process environment.

Examples:

```
yottadb -r start^%ydbwebreq --auth-stdin

Please enter usernames, passwords, authorization at the prompts:
Enter enter without entering a username to quit from the loop.

Username: *sam*
Password: *foo*
Authorization: *RW*

Username: *<enter>*
Starting Server at port 9080 in directory /home/sam/work/gitlab/MWS/build/ at logging level 0 using authentication
```

and

```
ydbgui_users="sam:foo:RW" yottadb -r %ydbwebreq
Starting Server at port 9080 in directory /home/sam/work/gitlab/MWS/build/ at logging level 0 using authentication
```

# Login/Token/Logout workflow
Once you have authentication enabled, all REST endpoints defined in your
`_ydbweburl` file will be protected. However, these endpoints are always
available from the server:

- `/api/ping`
- `/api/version`
- `/api/login`
- `/api/logout`
- `/api/auth-mode`

If you try to call any other end point without authentication or with a bad
token, you will get the following:

```
curl -Ss localhost:9080/test/json | jq
{
  "apiVersion": 1.1,
  "error": {
    "code": 403,
    "errors": [
      {
        "errname": "Forbidden",
        "message": "Forbidden",
        "reason": 403
      }
    ],
    "request": "GET /test/json ",
    "toperror": "Forbidden"
  }
}
```

To login, POST a JSON of { "username": "xxx", "password": "xxx" } to /api/login.
You will be sent back a token in the body as { "token": "xxx", "authorization":
"RO", timeout:900 }. You will get 401 Unauthorized if username/password is not specified
correctly.

For example:

```
curl -H 'Content-Type: application/json' -d '{ "username": "sam", "password": "foo" }' localhost:9080/login
{"authorization":"RW","timeout":900,"token":"F3joHQj0kyt1Df8ZglOp40"}
```

If you need to know whether you need to log-in, `/api/auth-mode` will return
`{ "auth": true/false }` depending on whether you need to log-in or not.

To authenticate each request, send the token in the `Authorization: Bearer`
header. If you don't send it, or send a bad token, you will get
an error of 403 Forbidden.

```
curl -H 'Authorization: Bearer F3joHQj0kyt1Df8ZglOp40' -v localhost:9080/test/json
{"foo":["boo","doo","loo"]}
```

Once you are done with your session, you can invalidate the token by logging
out. To logout, send the token back in the `Authorization` header using a GET call.

```
$ curl -H 'Authorization: Bearer F3joHQj0kyt1Df8ZglOp40' localhost:9080/api/logout
{"status":"OK"}
```

Logging out again is allowed (you will get an HTTP 200 back), but the `status` will say `token not found`.

If a token is timed out (by default, it will be timed out in 15 minutes from
its last use), you will get an HTTP 408 back, with a message of "Token
timeout".

Tokens are cleaned at 10 times the timeout. In the default case, they will be
cleaned in 150 minutes from the last time the token is used. In this case, you
will get a  403 with a message of "Forbidden".

The default timeout can be changed by using `--token-timeout`.  See below for
more details.

# Authorization
Currently, nothing is done with the authorization of RO/RW except to populate
the `HTTPREADWRITE` variable. It's the responsibility of the end application to
check this variable for how it wants to use it. If you use other authorizations
besides "RW", `HTTPREADWRITE` will remain zero.

# Miscelleanous considerations
## Using `--token-timeout {n}`

`--token-timeout {n}`, where n is the number of seconds, is another flag
associated with authentication. It's the timeout when a token that was obtained
via a log-in will be considered expired.  The default token timeout is 15
minutes. `--token-timeout 0` will run the server with no timeouts. This can be
useful for machine to machine communication where no timeout behavior is
desired.

## Debugging token issues in development
The server supports 4 logging levels; 0 means no logs (except the start-up
line), and then 1-3 are increasing log levels; higher levels include lower level logs.

Log level 1 show the location of the created database:
```
<PARENT> - - [14/APR/2023 12:08:08 PM] Created database - global directory: /tmp/yottadb/r999_x86_64/ydbgui94468.gld
<PARENT> - - [14/APR/2023 12:08:08 PM]                  - database file   : /tmp/yottadb/r999_x86_64/ydbgui94468.dat
```

Log Level 2 shows before each request every timeout interval (15 minutes by default):
```
<PARENT> - - [14/APR/2023 12:19:28 PM] Cleaning Tokens
```

Log level 3 shows (sensitive) information on all user hashes and tokens every 10 seconds of inactivity:
```
<PARENT> - - [14/APR/2023 12:11:08 PM] Users
^users("d6AyoeTJ7tSyz21TuGsw0E")="RW"
<PARENT> - - [14/APR/2023 12:11:08 PM] Tokens
^tokens("v6rLcA6VSsd7IHtGWzkD6B")="1681488658746732^RW"
^tokensByTime(1681488658746732,"v6rLcA6VSsd7IHtGWzkD6B")=""
```
