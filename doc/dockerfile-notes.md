[//]: #  Copyright (c) 2022 YottaDB LLC
[//]: #
[//]: #  Licensed under the Apache License, Version 2.0 (the "License");
[//]: #  you may not use this file except in compliance with the License.
[//]: #  You may obtain a copy of the License at
[//]: #
[//]: #      http://www.apache.org/licenses/LICENSE-2.0
[//]: #
[//]: #  Unless required by applicable law or agreed to in writing, software
[//]: #  distributed under the License is distributed on an "AS IS" BASIS,
[//]: #  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
[//]: #  See the License for the specific language governing permissions and
[//]: #  limitations under the License.

Dockerfile Notes
----------------
- To build docker image/run tests, do this:

```
docker build -t mws .
```

Several ways to use this:

```
# Run Server on port 9080
docker run -v $PWD/src:/mwebserver/r --rm -it -p 9080:9080 mws server
# Run Server on port 9080 with level 2 verbosity
docker run -v $PWD/src:/mwebserver/r --rm -it -p 9080:9080 mws server 2
# Run Tests
docker run -v $PWD/src:/mwebserver/r --rm mws tests
# Run Bash
docker run -v $PWD/src:/mwebserver/r --rm -it -p 9080:9080 mws bash
# Run debugger (starts server on 9080, and you need to zstep into)
docker run --rm -it -p 9080:9080 mws debug
# Run Server TLS on port 9080:
docker run -p 9080:9080 -v $PWD/src:/mwebserver/r --rm -it mws server-tls
# Run Debug TLS on port 9080:
docker run -p 9080:9080 -v $PWD/src:/mwebserver/r --rm -it mws debug-tls
# Run YDBGUI
docker run -p 9080:9080 -v $PWD/src:/mwebserver/r --rm -it mws ydbgui
```

At the same time, you can modify the source code in the `src` directory and see
the changes live.
