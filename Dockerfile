#   Copyright (c) 2023-2025 YottaDB LLC
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

# To build a YDB Web Server Docker image and run tests, run:
# docker build -t mws .
# Run Tests
# docker run -v $PWD/src:/mwebserver/r --rm mws tests

# Various other commands:
# Run Server on port 9080
# docker run -v $PWD/src:/mwebserver/r --rm -it -p 9080:9080 mws server
#
# Run Server on port 9080 with level 2 verbosity
# docker run -v $PWD/src:/mwebserver/r --rm -it -p 9080:9080 mws server 2
#
# Run Bash
# docker run -v $PWD/src:/mwebserver/r --rm -it -p 9080:9080 mws bash
#
# Run debugger (starts server on 9080, and you need to zstep into)
# docker run --rm -it -p 9080:9080 mws debug [entrypoint]
#
# Run Server TLS on port 9080
# docker run -p 9080:9080 -v $PWD/src:/mwebserver/r --rm -it mws server-tls
#
# Run Debug TLS on port 9080:
# docker run -p 9080:9080 -v $PWD/src:/mwebserver/r --rm -it mws debug-tls

FROM yottadb/yottadb-base:latest-master

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl libcurl4-openssl-dev git make cmake pkg-config gcc openssl libssl-dev libconfig-dev libgcrypt-dev libgpgme-dev libicu-dev iproute2 libsodium-dev

ENV ydb_dist="/opt/yottadb/current"
ENV gtm_dist="/opt/yottadb/current"
ENV ydb_chset="utf-8"
ENV ydb_xc_libcurl="/opt/yottadb/current/plugin/libcurl.xc"
RUN mkdir -p /mwebserver/o /mwebserver/r
ENV ydb_routines="/mwebserver/o*(/mwebserver/r) /opt/yottadb/current/utf8/libyottadbutil.so /opt/yottadb/current/plugin/o/utf8/_ydbmwebserver.so"
ENV ydb_icu_version="74"

# Install cURL plugin
RUN git clone https://github.com/shabiel/fis-gtm-plugins.git
RUN cd fis-gtm-plugins/libcurl && make install

# Install Encryption Plugin
RUN git clone https://gitlab.com/YottaDB/Util/YDBEncrypt
RUN cd YDBEncrypt && make install

EXPOSE 9080

RUN mkdir -p /mwebserver/certs
RUN openssl genrsa -aes128 -passout pass:ydbgui -out /mwebserver/certs/ydbgui.key 2048
RUN openssl req -new -key /mwebserver/certs/ydbgui.key -passin pass:ydbgui -subj '/C=US/ST=Pennsylvania/L=Malvern/CN=localhost' -out /mwebserver/certs/ydbgui.csr
RUN openssl req -x509 -days 365 -sha256 -in /mwebserver/certs/ydbgui.csr -key /mwebserver/certs/ydbgui.key -passin pass:ydbgui -out /mwebserver/certs/ydbgui.pem
COPY ci/ydbgui.ydbcrypt /mwebserver/certs/
ENV ydb_crypt_config=/mwebserver/certs/ydbgui.ydbcrypt

# Download YDBCMake & YDBSodium (so we don't download it in the YDB-Web-Server)
RUN git clone https://gitlab.com/YottaDB/Tools/YDBCMake.git
RUN git clone https://gitlab.com/YottaDB/Util/YDBSodium.git

# Install YDB-Web-Server
COPY src/ src/
COPY CMakeLists.txt .
COPY _ydbmwebserver.manifest.json.in .
RUN mkdir build && cd build && cmake -D FETCHCONTENT_SOURCE_DIR_YDBCMAKE=../YDBCMake -D FETCHCONTENT_SOURCE_DIR_YDBSODIUM=../YDBSodium .. && make install

# Copy these files which are not installed by default
COPY src/_ydbwebtest.m src/_ut.m src/_ut1.m src/_ydbwebjsonDecodeTest.m src/_ydbwebjsonEncodeTest.m src/_ydbwebjsonTestData1.m src/_ydbwebjsonTestData2.m src/_ydbweburl.m /mwebserver/r/

# Copy Test script
COPY ci/run_test.sh /mwebserver/run_test.sh

ENTRYPOINT ["/mwebserver/run_test.sh"]
