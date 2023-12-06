# M Web Server
This source tree represents a web (HTTP) server implemented in the M language.

## Purpose
The M Web Server (MWS) provides for a way to serve web services from the M
Databases. It does that by mapping URLs to M procedures that retrieve or save
the data depending on the request. The mapping is dynamic and depends on a developer
provided file.

MWS provides the following features:

 - It is completely stateless.
 - It runs plain RESTful web services rather than implementing a custom protocol.
 - It does not introduce any new data structures.
 - It fully supports JSON out of the box, automatically encoding and decoding
   JSON requests.
 - It is simple to deploy.
 - The software can also serve file-system based resources that can take
   advantage of the web services.
 - Optional gzip compression

# Installation instructions
## Dependencies
- YottaDB must be installed
- Operational: libsodium (supplied by libsodium-dev[el] package)(optional), gzip (optional), date. 
- Installer only: cmake, pkg-config, ld.gold.

## Installation
Download this repository (git or [download zip](https://gitlab.com/YottaDB/Util/YDB-Web-Server/-/archive/master/YDB-Web-Server-master.zip) and unzip)

Create a build directory in the root of the repository:

    mkdir build
    cd build

Run cmake to generate the Makefiles

    cmake ..

Install the plugin

    [sudo] make install

## Uninstalling
Run the following in the same build directory:
```
[sudo] xargs rm < install_manifest.txt
```

# Starting and Stopping the Server
To start the server, run `$ydb_dist/yottadb -run start^%ydbwebreq` (with --port <nnnn>). If you don't
specify a port, it will start at port number 9080.

You can stop the server using `$ydb_dist/yottadb -run stop^%ydbwebreq [--port <nnnn>]`.

A full list of the options accepted is as follows:

* `--auth-stdin` Start server asking for users and save to file `users.json`.
  *Requires that libsodium is installed.*
* `--auth-file /x/y/z` Start server using in `/x/y/z`. *Requires that libsodium
  is installed.*
* `--debug` Start server in non-forking mode with $ETRAP set to BREAK. Server
  will only handle a single request before terminating. Use this to debug
  problems with the web server.
* `--directory /x/y/z` Serve static files from directory /x/y/z.
* `--gzip` Enable gzipping from the server side. The default is to not gzip.
  Gzipping used the `/dev/shm` file system for temporary files; if the space is
  limited (e.g. in docker images), you may face problems with gzipping.
* `--log n` A logging level. By default the level is 0. It can be 0-3, with 3
  being most verbose.
* `--port nnn` port to listen on.
* `--tlsconfig tls-config-name` A TLS configuration with a name in the
  `ydb_crypt_config` file. TLS set-up is somewhat complex. See
  https://docs.yottadb.com/ProgrammersGuide/ioproc.html#tls-on-yottadb for
  instructions, and [Dockerfile](Dockerfile) and
  [docker-startup.sh](docker-configuration/docker-startup.sh) for its
  implementation. Note that due to the design of the YottaDB TLS plug-in code,
  you need to specify different values for `--tlsconfig`: to start look for a server
  entry, and stop look for a client entry.
* `--token-timeout n` Time out tokens (when using either of the auth options)
  even n seconds. If n is 0, then tokens are not timed out.
* `--readwrite` An application level flag to indicate that an application is
  readwrite. The flag does not change any of the behavior of the web server
  itself. Available in variable `httpreadwrite`.
* `--ws-port nnnnn` An application level flag to tell the application where
  a web socket server will be located. This server itself does not implement
  web sockets. Available in variable `httpoptions("ws-port")`.
* `--client-config /x/y/z` An application level flag to tell the application
  where a client configuration file is located on the file system. The server
  itself does not use this. Available in variable
  `httpoptions("client-config")`.

Full documentation is located [here](https://docs.yottadb.com/Plugins/ydbwebserver.html).
