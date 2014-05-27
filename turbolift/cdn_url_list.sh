#!/usr/bin/env bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Export the following variables and or modify this script with the following data
# Variables:
#   CLOUD_USERNAME="The username of the cloud user"
#   CLOUD_APIKEY="The API Key of the cloud user"
#   CLOUD_REGION="The Region of the cloud user"
#   CLOUD_CDNURL_TYPE="The cdn url type to build with"
#     Available Values: x-cdn-ssl-uri, x-cdn-ios-uri, x-cdn-uri, x-cdn-streaming-uri
#   CDNURLS_LOG="Name of this log file"

USERNAME="${CLOUD_USERNAME}"
APIKEY="${CLOUD_APIKEY}"
REGION="${CLOUD_REGION}"

CDN_URL_TYPE=${CLOUD_CDNURL_TYPE:-"x-cdn-ssl-uri"}
CDNURLS_LOG=${CDNURLS_LOG:-"$HOME/cdnfiles.log"}

if [ -f "$CDNURLS_LOG" ];then
  mv $CDNURLS_LOG $CDNURLS_LOG.bak
fi

# Grab the CDN URL from the container
TBLCMD="turbolift  -u $USERNAME -a $APIKEY"
CDN_VAR=$($TBLCMD --os-rax-auth $REGION show -c cdn --cdn-info | grep $CDN_URL_TYPE | awk '{print $4}')

# Build all of the URLS that are found
for i in $($TBLCMD --os-rax-auth $REGION list -c cdn | awk '/\|/ {print $4}'); do 
  echo "$CDN_VAR/$i" | tee -a $CDNURLS_LOG
done

echo "Data can be found here: $CDNURLS_LOG"
