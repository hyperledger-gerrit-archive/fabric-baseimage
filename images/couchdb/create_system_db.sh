#!/bin/bash
#Copyright IBM Corp. All Rights Reserved.
#
#SPDX-License-Identifier: Apache-2.0
#

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
