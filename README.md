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
 - It fully supports JSON out of the box; XML is also supported.
 - It is simple to deploy.
 - The software can also serve file-system based resources that can take
   advantage of the web services.

# Installation instructions
## Dependencies
- Operational: gzip (optional), date, sed. 
- Installer only: cmake.

## Installation
The tests are not imported as the plugin support is intended to be ran on
production envrionments.

Create a build directory:

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
  implementation.
* `--tls client`. Only used by `stop^%ydbwebreq`. Will be deprecated in favor
  of `--tlsconfig`.
* `--readwrite` An application level flag to indicate that an application is
  readwrite. The flag does not change any of the behavior of the web server
  itself. 
* `--userpass xxx:yyy` Don't use. Will be deprecated soon.

# Developer Documentation
See the [doc](doc) folder.

To set-up TLS, see [doc/tls-setup.md](doc/tls-setup.md).

# Testing Documentation
There are extensive [unit tests](doc/testing.md) with coverage.
