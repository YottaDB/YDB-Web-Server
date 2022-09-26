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

export USER=root # needed for maskpass
export ydb_tls_passwd_ydbgui="$(echo ydbgui | /opt/yottadb/current/plugin/gtmcrypt/maskpass | cut -d ":" -f2 | tr -d '[:space:]')"
export ydb_tls_passwd_client="$(echo ydbgui | /opt/yottadb/current/plugin/gtmcrypt/maskpass | cut -d ":" -f2 | tr -d '[:space:]')"
#echo "export ydb_tls_passwd_client=$ydb_tls_passwd_client" >> $HOME/.bashrc
echo "export PATH=/opt/yottadb/current/:$PATH" >> $HOME/.bashrc

if   [ "$1" = "server" ]; then
	exec /opt/yottadb/current/yottadb -r %XCMD 'do start^%ydbwebreq(9080)'
elif [ "$1" = "server-tls" ]; then
	exec /opt/yottadb/current/yottadb -r %XCMD 'do start^%ydbwebreq(9080,0,"ydbgui")'
elif [ "$1" = "bash" ] || [ "$1" = "shell" ]; then
	exec /bin/bash
elif [ "$1" = "debug" ]; then
	export ydb_zstep='n oldio s oldio=$io u 0 zp @$zpos b  u oldio'
	exec /opt/yottadb/current/yottadb -r %XCMD 'zb start^%ydbwebreq do start^%ydbwebreq(9080,1)'
elif [ "$1" = "debug-tls" ]; then
	export ydb_zstep='n oldio s oldio=$io u 0 zp @$zpos b  u oldio'
	exec /opt/yottadb/current/yottadb -r %XCMD 'zb TLS^%ydbwebreq do start^%ydbwebreq(9080,1,"ydbgui")'
else # "$1" = "test"
	/opt/yottadb/current/yottadb -r ^%ydbwebtest | tee test_output.txt

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
