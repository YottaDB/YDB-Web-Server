#   Copyright (c) 2022 YottaDB LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
FROM yottadb/yottadb-base:latest-master

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y libcurl4-openssl-dev git make gcc

# Install cURL plugin
RUN git clone https://github.com/shabiel/fis-gtm-plugins.git
ENV LD_LIBRARY_PATH /opt/yottadb/current
ENV ydb_chset utf-8
RUN cd fis-gtm-plugins/libcurl && \
    . /opt/yottadb/current/ydb_env_set && \
    make install

# Install M-Unit
RUN git clone https://github.com/ChristopherEdwards/M-Unit.git munit

RUN cd munit && \
    mkdir r && \
    cd Routines && \
    for file in _*.m; do mv $file /data/munit/r/; done

# Install M-Web-Server
COPY ./src /mwebserver/r

# Copy Test script
COPY ci/run_test.sh /mwebserver/run_test.sh
ENV GTMXC_libcurl "/opt/yottadb/current/plugin/libcurl_ydb_wrapper.xc"
ENV ydb_routines "/data/r1.35_x86_64/o*(/mwebserver/r /data/munit/r)"
ENTRYPOINT ["/mwebserver/run_test.sh"]
