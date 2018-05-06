#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

counter=0
while true
do

  #sleep before the attempts to allow the server to come up
  sleep 5

  #Check to see if CouchDB has started
  STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:5984)
  if [ $STATUS_CODE -eq 200 ]; then

    STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:5984/$1)
    if [ $STATUS_CODE -eq 200 ]; then
      echo "Found system database $1"
      break
    else
      echo "Creating $1 database"
      STATUS_CODE=$(curl -X PUT -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5984/$1)
      if [ $STATUS_CODE -eq 201 ]; then
        break
      fi
    fi

  else
    echo "Server start was not detected, retrying in 5 sec"
  fi

  #Don't loop forever, exit after 5 minutes
  let counter++
  if [[ "$counter" -gt 60 ]]; then
   echo "Retries completed, exiting without creating system databases."
   exit 1
 fi

done
