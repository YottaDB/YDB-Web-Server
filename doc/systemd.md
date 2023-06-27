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

# Introduction
The previous versions of the Web Server hosted on Github supported the job
command to run the server in the background. This has been removed, for several
reasons:

- Once the job is created, it's hard to find out about it, resulting in
  users trying to start the server again.
- As a developer, because a lot of code ran in the background,
  troubleshooting start-up problems was hard.
- There were too many ways to start the server, confusing the users.
- With Docker, to control the start-up and shutdown of the process, it's
  much easier to have a single main process that can be started and stopped
  in an obvious way.
- A jobbed process output is hidden and it's hard to expose it to standard output

The server now starts and runs in the foreground until a signal 2 (CTRL-C) or a
signal 15 ([MUPIP STOP](https://docs.yottadb.com/AdminOpsGuide/dbmgmt.html#stop)) 
is received. To run it in the background, either use your shell's job control
or use [systemd](https://systemd.io/).

# Systemd Set-up
Create a file **`/lib/systemd/system/ydb-web-server.service`** that looks like
this, replacing the paths with paths appropriate to your system. Note that
there are many other ways to do this (e.g. using `EnvironmentFile` for YottaDB
environment variables; or offloading the entire set-up to a script); this is a
minimal example to show you how to do it.
```
[Unit]
Description=YottaDB Web Server
After=network.target

[Service]
Type=exec
User=xxx
Environment='ydb_dist=/usr/local/lib/yottadb/r138'
Environment='ydb_routines=$ydb_dist/plugin/o/_ydbmwebserver.so $ydb_dist/libyottadbutil.so'
ExecStart=/usr/bin/env "${ydb_dist}/yottadb" -run start^%%ydbwebreq --directory /var/www --port 9080 --log 1
ExecStop=/usr/bin/env "${ydb_dist}/yottadb" -run stop^%%ydbwebreq --port 9080
Restart=never
```

Load the file, enable it (so it will start on reboot), check enable status,
start, check start status:
```
systemctl daemon-reload
systemctl enable ydb-web-server
systemctl is-enabled ydb-web-server
systemctl status ydb-web-server
systemctl start ydb-web-server
systemctl status ydb-web-server
```

You can also try the following as well:
```
systemctl stop ydb-web-server
systemctl restart ydb-web-server
journalctl -xeu ydb-web-server
```
