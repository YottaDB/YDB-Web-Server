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
# TLS Set-up on YottaDB 
Setting up TLS is usually hard. These instructions are provided in the hope that they 
can guide you, but there is not guarantee that they will work. Comments inline.

# Install
See https://gitlab.com/YottaDB/Util/YDBEncrypt for instructions.

# Certificate Set-up
```
# Go to your database
cd /data

# Create your certificate with a key that has a password. I know from previous
# interaction with the GT.M developers is that they don't allow passwordless keys
# for business reasons. Here's is how I did it; but you may already have a
# certificate. I moved all the files into a cert directory after this.
openssl genrsa -aes128 -passout pass:monkey1234 -out ./mycert.key 2048
openssl req -new -key ./mycert.key -passin pass:monkey1234 -subj '/C=US/ST=Washington/L=Seattle/CN=www.smh101.com' -out ./mycert.csr
openssl req -x509 -days 365 -sha256 -in ./mycert.csr -key .//mycert.key -passin pass:monkey1234 -out ./mycert.pem
mkdir certs
mv mycert.* certs/

# Create a file (name doesn't matter) called ydbcrypt_config.libconfig with the
# following contents. Note the section called dev. This can be called anything.
# It lets you put a pair of cert/key for each environment you need to configure.
cat ydbcrypt_config.libconfig
tls: {
  dev: {
    format: "PEM";
    cert: "/data/certs/mycert.pem";
    key:  "/data/certs/mycert.key";
  }
}

# In your file that sets up the YottaDB environment, add set the env variable
# ydbcrypt_config to be the path to your config file:
export ydbcrypt_config="/data/ydbcrypt_config.libconfig"

# Find out the hash of your key password using the maskpass utility
$ydb_dist/plugin/ydbcrypt/maskpass <<< 'monkey1234' | cut -d ":" -f2 | tr -d ' '

# In your environment file, ydbtls_passwd_{section name} to be that hash. For me, it's:
export ydbtls_passwd_dev="30A22B54B46618B4361F"

# Run the server like this, substituting the {section name} appropriately. here it is dev
$ydb_dist/mumps -r %XCMD 'do start^%ydbwebreq(9080,0,"dev")'

# Test the server like this (cacert to supply curl with the self-signed Certificate)
curl --cacert /data/certs/mycert.pem https://localhost:9080
```

Sample Log output:
```
Starting Server at port 9080 using TLS configuration dev
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:52 PM] Starting Child at PID 13 from parent 1
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:52 PM] TLS Connection Data:
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:52 PM]             $DEVICE: 1,Connection reset by peer
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:52 PM]                $KEY: ESTABLISHED|h1663247992000|::ffff:172.17.0.1
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:52 PM]               $TEST: 0
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:52 PM] Disconnect/Halt 13
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM] Starting Child at PID 15 from parent 1
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM] TLS Connection Data:
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM]             $DEVICE: 0
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM]                $KEY: ESTABLISHED|h1663247998000|::ffff:172.17.0.1
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM]               $TEST: 1
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM] GET / HTTP/1.1
::ffff:172.17.0.1 - - [15/SEP/2022 01:19:58 PM] Disconnect/Halt 15
```
