#!/usr/bin/env bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script will either start the kafka server, or run the user
# specified command.

# Exit immediately if a pipeline returns a non-zero status.
set -e

KAFKA_HOME=/opt/kafka
KAFKA_EXE=${KAFKA_HOME}/bin/kafka-server-start.sh
KAFKA_SERVER_PROPERTIES=${KAFKA_HOME}/config/server.properties

# handle starting the kafka server with an option
# (genericly handled, but only --override known to me at this time)
if [ "${1:0:1}" = '-' ]; then
  set -- ${KAFKA_EXE} ${KAFKA_SERVER_PROPERTIES} "$@"
fi

# handle default (i.e. no custom options or commands)
if [ "$1" = "${KAFKA_EXE}" ]; then

  # add the server.properties to the command
  set -- ${KAFKA_EXE} ${KAFKA_SERVER_PROPERTIES}

  # compute the advertised host name if a command was specified
  if [[ -z ${KAFKA_ADVERTISED_HOST_NAME} && -n ${KAFKA_ADVERTISED_HOST_NAME_COMMAND} ]] ; then
    export KAFKA_ADVERTISED_HOST_NAME=$(eval ${KAFKA_ADVERTISED_HOST_NAME_COMMAND})
  fi

  # compute the advertised port if a command was specified
  if [[ -z ${KAFKA_ADVERTISED_PORT} && -n ${KAFKA_ADVERTISED_PORT_COMMAND} ]] ; then
    export KAFKA_ADVERTISED_PORT=$(eval ${KAFKA_ADVERTISED_PORT_COMMAND})
  fi

  # default to auto set the broker id
  if [ -z "$KAFKA_BROKER_ID" ] ; then
    export KAFKA_BROKER_ID=-1
  fi

  # fix log.retention.(time) to -1 so time-based log retention is disabled
  # even though this is strictly REQUIRED at present, we still respect user
  # envvar here, because we want user to be able to set this property when
  # we enable orderer ledger pruning.
  if [ -z "$KAFKA_LOG_RETENTION_MS" ] ; then
    export KAFKA_LOG_RETENTION_MS=-1
  fi

  # add newline to end of server.properties if missing
  tail -c 1 ${KAFKA_SERVER_PROPERTIES} | read -r _ || printf "\n" >> ${KAFKA_SERVER_PROPERTIES}

  # update server.properties by searching for envinroment variables named
  # KAFKA_* and converting them to properties in the kafka server properties file.
  for ENV_ENTRY in $(env | grep "^KAFKA_") ; do
    # skip some entries that should do not belong in server.properties
    if [[ $ENV_ENTRY =~ ^KAFKA_HOME= ]] ; then continue ; fi
    if [[ $ENV_ENTRY =~ ^KAFKA_EXE= ]] ; then continue ; fi
    if [[ $ENV_ENTRY =~ ^KAFKA_VERSION= ]] ; then continue ; fi
    if [[ $ENV_ENTRY =~ ^KAFKA_DOWNLOAD_SHA1= ]] ; then continue ; fi
    if [[ $ENV_ENTRY =~ ^KAFKA_SERVER_PROPERTIES= ]] ; then continue ; fi
    if [[ $ENV_ENTRY =~ ^KAFKA_ADVERTISED_HOST_NAME_COMMAND= ]] ; then continue ; fi
    if [[ $ENV_ENTRY =~ ^KAFKA_ADVERTISED_PORT_COMMAND= ]] ; then continue ; fi
    # transform KAFKA_XXX_YYY to xxx.yyy
    KAFKA_PROPERTY_NAME="$(echo ${ENV_ENTRY%%=*} | sed -e 's/^KAFKA_//;s/_/./g' | tr '[:upper:]' '[:lower:]')"
    # get property value
    KAFKA_PROPERTY_VALUE="${ENV_ENTRY#*=}"
    # update server.properties
    if grep -q "^\s*#\?\s*${KAFKA_PROPERTY_NAME}" ${KAFKA_SERVER_PROPERTIES} ; then
      # the property is already defined (maybe even commented out), so edit the file
      sed -i -e "s|^\s*${KAFKA_PROPERTY_NAME}\s*=.*$|${KAFKA_PROPERTY_NAME}=${KAFKA_PROPERTY_VALUE}|" ${KAFKA_SERVER_PROPERTIES}
      sed -i -e "s|^\s*#\s*${KAFKA_PROPERTY_NAME}\s*=.*$|${KAFKA_PROPERTY_NAME}=${KAFKA_PROPERTY_VALUE}|" ${KAFKA_SERVER_PROPERTIES}
    else
      echo "${KAFKA_PROPERTY_NAME}=${KAFKA_PROPERTY_VALUE}">>${KAFKA_SERVER_PROPERTIES}
    fi
  done
fi

exec "$@"
