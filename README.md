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
- Operational: gzip, date, sed. 
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
You can stop the server using `do stop^%webreq`.

To start it again, run `do job^%webreq(portno)`, substituting a port number
of your choice. If you run `do [go]^%webreq`, it will start at port number 9080.

# Developer Documentation
See the [doc](doc) folder.

To make a new version, see [doc/packaging.md](doc/packaging.md).

To set-up TLS, see [doc/tls-setup.md](doc/tls-setup.md).

# Testing Documentation
There are extensive [unit tests](doc/testing.md) covering 80% of
the code.
