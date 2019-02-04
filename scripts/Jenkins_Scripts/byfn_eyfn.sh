#!/bin/bash -e
#
# SPDX-License-Identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 IBM Corporation, The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License 2.0
# which accompanies this distribution, and is available at
# https://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Clone fabric samples repository
WD="$WORKSPACE/gopath/src/github.com/hyperledger/fabric-samples"
git clone --single-branch -b $GERRIT_BRANCH --depth 2 https://github.com/hyperledger/fabric-samples $WD
echo -e "\033[32m cloned fabric-samples repository" "\033[0m"
cd $WD || exit
git checkout $GERRIT_BRANCH

echo "-------> GERRIT_BRANCH: $GERRIT_BRANCH"
FABRIC_SAMPLES_COMMIT=$(git log -1 --pretty=format:"%h")
echo "FABRIC_SAMPLES_COMMIT ========> $FABRIC_SAMPLES_COMMIT" >> ${WORKSPACE}/gopath/src/github.com/hyperledger/commit.log
echo -e "\033[32m Execute Byfn and Eyfn Tests" "\033[0m"

# docker container list
CONTAINER_LIST=(peer0.org1 peer1.org1 peer0.org2 peer1.org2 peer0.org3 peer1.org3 orderer)
COUCHDB_CONTAINER_LIST=(couchdb0 couchdb1 couchdb2 couchdb3 couchdb4 couchdb5)

cd gopath/src/github.com/hyperledger/fabric-samples || exit
# copy /bin directory to fabric-samples

if [ "$ARCH" == "s390x" ]; then
   cp -r $WORKSPACE/gopath/src/github.com/hyperledger/fabric/release/linux-s390x/bin/ .
elif [ "$ARCH" == "ppc64le" ]; then
   cp -r $WORKSPACE/gopath/src/github.com/hyperledger/fabric/release/linux-ppc64le/bin/ .
else
   cp -r $WORKSPACE/gopath/src/github.com/hyperledger/fabric/release/linux-amd64/bin/ .
fi

cd first-network || exit

# Create Logs directory
mkdir -p $WORKSPACE/Docker_Container_Logs

#Set INFO to DEBUG
sed -it 's/INFO/DEBUG/' base/peer-base.yaml

export PATH=gopath/src/github.com/hyperledger/fabric-samples/bin:$PATH

artifacts() {

    echo "---> Archiving generated logs"
    rm -rf $WORKSPACE/archives
    mkdir -p "$WORKSPACE/archives"
    mv "$WORKSPACE/Docker_Container_Logs" $WORKSPACE/archives/
}

# Capture docker logs of each container
logs() {

for CONTAINER in ${CONTAINER_LIST[*]}; do
    docker logs $CONTAINER.example.com >& $WORKSPACE/Docker_Container_Logs/$CONTAINER-$1.log
    echo
done

if [ ! -z $2 ]; then

    for CONTAINER in ${COUCHDB_CONTAINER_LIST[*]}; do
        docker logs $CONTAINER >& $WORKSPACE/Docker_Container_Logs/$CONTAINER-$1.log
        echo
    done
fi
}

copy_logs() {

# Call logs function
logs $2 $3

if [ $1 != 0 ]; then
    artifacts
    exit 1
fi
}

echo "------> Deleting Containers...."
# shellcheck disable=SC2046
docker rm -f $(docker ps -aq)
echo "------> List Docker Containers"
docker ps -aq

# Execute below tests
echo "------> BRANCH: " $GERRIT_BRANCH
if [ $GERRIT_BRANCH != "release-1.0" ]; then

        echo "############## BYFN,EYFN DEFAULT CHANNEL TEST ###########"
        echo "#########################################################"

        echo y | ./byfn.sh -m down
        echo y | ./byfn.sh -m up -t 60
        copy_logs $? default-channel
        echo y | ./eyfn.sh -m up -t 60
        copy_logs $? default-channel
        echo y | ./eyfn.sh -m down
        echo
        echo "############## BYFN,EYFN CUSTOM CHANNEL TEST ############"
        echo "#########################################################"

        echo y | ./byfn.sh -m up -c custom-channel -t 60
        copy_logs $? custom-channel
        echo y | ./eyfn.sh -m up -c custom-channel -t 60
        copy_logs $? custom-channel
        echo y | ./eyfn.sh -m down
        echo
        echo "############### BYFN,EYFN CUSTOM CHANNEL WITH COUCHDB TEST ##############"
        echo "#########################################################################"

        echo y | ./byfn.sh -m up -c custom-channel-couchdb -s couchdb -t 60 -d 15
        copy_logs $? custom-channel-couch couchdb
        echo y | ./eyfn.sh -m up -c custom-channel-couchdb -s couchdb -t 60 -d 15
        copy_logs $? custom-channel-couch couchdb
        echo y | ./eyfn.sh -m down
        echo
        echo "############### BYFN,EYFN WITH NODE Chaincode. TEST ################"
        echo "####################################################################"

        echo y | ./byfn.sh -m up -l node -t 60
        copy_logs $? default-channel-node
        echo y | ./eyfn.sh -m up -l node -t 60
        copy_logs $? default-channel-node
        echo y | ./eyfn.sh -m down

        echo "############### FABRIC-CA SAMPLES TEST ########################"
        echo "###############################################################"
        cd ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-samples/fabric-ca || exit
        ./start.sh && ./stop.sh

else
        echo "############## BYFN DEFAULT CHANNEL TEST#########################"
        echo "#################################################################"
        echo y | ./byfn.sh -m down
        echo y | ./byfn.sh -m up -t 60
        copy_logs $? default-channel
        echo y | ./byfn.sh -m down
        echo

        echo "############## BYFN CUSTOM CHANNEL TEST #################"
        echo "#########################################################"
        echo y | ./byfn.sh -m up -c custom-channel -t 60
        copy_logs $? custom-channel

        echo "############### BYFN CUSTOM CHANNEL WITH COUCHDB TEST ###################"
        echo "#########################################################################"
        echo y | ./byfn.sh -m down
        echo y | ./byfn.sh -m up -c custom-channel-couchdb -s couchdb -t 60
        copy_logs $? custom-channel-couchdb couchdb
        echo y | ./byfn.sh -m down
fi
