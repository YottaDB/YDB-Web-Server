#!/bin/bash
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

set -e
set -o pipefail
# TODO: Remove this when we remove the use of globals completely
. /opt/yottadb/current/ydb_env_set 

if [ "$1" = "server" ]; then
	exec yottadb -r %XCMD 'do start^%webreq(9080)'
elif [ "$1" = "bash" ] || [ "$1" = "shell" ]; then
	exec /bin/bash
else # "$1" = "test"
	yottadb -r ^%webtest | tee test_output.txt

	set +e # grep will have status of 1 if no lines are found, and that will exit the script!
	grep -B1 -F '[FAIL]' test_output.txt
	grep_status=$?
	set -e
	# Check if we have M-Unit failures.
	if [ "$grep_status" -eq 1 ]; then
		exit 0
	else
		exit 1
	fi
fi
