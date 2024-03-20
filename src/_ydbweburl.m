%ydbweburl ;YottaDB/CJE -- URL Matching routine;Jun 20, 2022@14:48
	;
	; This routine is used to map URLs to entry points under
	; the URLMAP entry point.
	;
URLMAP ;
	;;GET test/r/{routine?.1"%25".32AN} routine^%ydbwebapi
	;;PUT test/r/{routine?.1"%25".32AN} putroutine^%ydbwebapi
	;;GET /test/error err^%ydbwebapi
	;;GET test/bigoutput bigoutput^%ydbwebapi
	;;GET test/gloreturn1 gloreturn1^%ydbwebapi
	;;GET test/gloreturn2 gloreturn2^%ydbwebapi
	;;GET test/gloreturn3 gloreturn3^%ydbwebapi
	;;GET /test/xml xml^%ydbwebapi
	;;GET /test/empty empty^%ydbwebapi
	;;GET test/customerror customerr^%ydbwebapi
	;;POST test/post posttest^%ydbwebapi
	;;GET test/utf8/get utf8get^%ydbwebapi
	;;POST test/utf8/post utf8post^%ydbwebapi
	;;GET test/json getjson^%ydbwebapi
	;;GET test/readwrite readwritetest^%ydbwebapi
	;;GET test/simtimeout simtimeout^%ydbwebapi
	;;GET test/simsodiumerr simsodiumerr^%ydbwebapi
	;;GET test/uppercase uppercase^%ydbwebapi
	;;GET test/zgbldir globaldir^%ydbwebapi
	;;GET test/cwd cwd^%ydbwebapi
	;;GET test/env env^%ydbwebapi
	;;GET test/gce gce^%ydbwebapi
	;;GET test/ws-port wsport^%ydbwebapi
	;;POST test/postchunked chunkedpost^%ydbwebapi
	;;GET test/getchunked chunkedget^%ydbwebapi
	;;zzzzz
	;
	; Copyright (c) 2019 Christopher Edwards
	; Copyright (c) 2019 Sam Habiel
	; Copyright (c) 2022-2024 YottaDB LLC
	;
	;Licensed under the Apache License, Version 2.0 (the "License");
	;you may not use this file except in compliance with the License.
	;You may obtain a copy of the License at
	;
	;    http://www.apache.org/licenses/LICENSE-2.0
	;
	;Unless required by applicable law or agreed to in writing, software
	;distributed under the License is distributed on an "AS IS" BASIS,
	;WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	;See the License for the specific language governing permissions and
	;limitations under the License.
