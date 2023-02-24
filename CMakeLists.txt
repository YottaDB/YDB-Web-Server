#   Copyright (c) 2022-2023 YottaDB LLC
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

# Prelim
cmake_minimum_required(VERSION 3.14)
include(ExternalProject)
include(FetchContent)

# The tag is at the time of writing the latest tag in YDBCMake.
# The tag is fixed at that point to ensure reproducible builds.
FetchContent_Declare(YDBCMake
	GIT_REPOSITORY	https://gitlab.com/YottaDB/Tools/YDBCMake.git
	GIT_TAG		e8d9a6d1209b0be88190056f9245671dfdee0713
)
# The following sets ydbcmake_SOURCE_DIR
FetchContent_MakeAvailable(YDBCMake)
message(STATUS "YDBCMake Source Directory: ${ydbcmake_SOURCE_DIR}")
set(CMAKE_MODULE_PATH "${ydbcmake_SOURCE_DIR}/ydbcmake/")

project(YDBWebServer
	LANGUAGES M
	VERSION 2.0.0)
find_package(YOTTADB REQUIRED)

# Sources
set(source_files
  src/_ydbwebapi.m
  src/_ydbwebhome.m
  src/_ydbwebjson.m
  src/_ydbwebjsonDecode.m
  src/_ydbwebjsonEncode.m
  src/_ydbwebreq.m
  src/_ydbwebrsp.m
  src/_ydbwebutils.m
)

add_ydb_library(_ydbmwebserver SOURCES ${source_files})
install_ydb_library(_ydbmwebserver)
