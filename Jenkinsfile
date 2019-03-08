#!groovy

// Copyright IBM Corp All Rights Reserved
//
// SPDX-License-Identifier: Apache-2.0
//

@Library("fabric-ci-lib") _ // global shared library from ci-management repository
timestamps { // set the timestamps on the jenkins console
  timeout(40) { // Build timeout set to 40 mins
    if(env.NODE_ARCH != "hyp-x") {
      node ('hyp-z') { // trigger jobs on s390x builds nodes
        env.NODE_VER = "8.14.0" // Set node version
        env.GOPATH = "$WORKSPACE/gopath"
        env.PATH = "$GOPATH/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/npm/bin:/home/jenkins/.nvm/versions/node/v${NODE_VER}/bin:$PATH"
        buildStages() // call buildStages
      } // End node
    } else {
      node ('hyp-x') { // trigger jobs on x86_64 builds nodes
        def nodeHome = tool 'nodejs-8.14.0'
        env.GOPATH = "$WORKSPACE/gopath"
        env.PATH = "$GOPATH/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${nodeHome}/bin:$PATH"
        buildStages() // call buildStages
      } // end node block
    }
  } // end timeout block
} // end timestamps block

def buildStages() {
    try {
      def ROOTDIR = pwd() // workspace dir (/w/workspace/<job_name>)
      def failure_stage = "none"
      // set MARCH value to amd64, s390x, ppc64le
      env. MARCH = sh(returnStdout: true, script: "uname -m | sed 's/x86_64/amd64/g'").trim()

      stage('Clean Environment') {
        // delete working directory
        deleteDir()
        // Clean build environment before start the build
        fabBuildLibrary.cleanupEnv()
        // Display jenkins environment details
        fabBuildLibrary.envOutput()
      }

      stage('Checkout SCM') {
        // Get changes from gerrit
        fabBuildLibrary.cloneRepo 'fabric-baseimage'
        // Load properties from ci.properties file
        props = fabBuildLibrary.loadProperties()
      }

      stage("Build Artifacts") {
        dir("$ROOTDIR/$BASE_DIR") {
            // Build Docker Images
            env.GOROOT = "/opt/go/go" + props["GO_VER"] + ".linux." + "$MARCH"
            GOPATH = "$WORKSPACE/gopath"
            env.PATH = "$GOROOT/bin:$GOPATH/bin:$PATH"
            fabBuildLibrary.fabBuildImages('fabric', 'docker dependent-images')
        }
      }

// Publish npm modules only from amd64 merge jobs
if ((env.JOB_TYPE == "merge") && (env.MARCH = "amd64")) {
  Build_Artifacts()
  Pull_Artifacts()
  Byfn_Eyfn_Tests()
  UnitTests()
} else {
  echo "SKIP performing BYFN_EYFN tests and UNITTESTS from VERIFY job"
}
    } finally { // post build actions
        // Don't fail build if there is no coverage report file
        step([$class: 'CoberturaPublisher', autoUpdateHealth: false, autoUpdateStability: false,
              coberturaReportFile: '**/cobertura-coverage.xml', failUnhealthy: false, failUnstable: false,
              failNoReports: false, maxNumberOfBuilds: 0, onlyStable: false, sourceEncoding: 'ASCII',
              zoomCoverageChart: false])
        // Don't fail build if there is no log file
        archiveArtifacts allowEmptyArchive: true, artifacts: '**/*.log'
        // Send notifications only for merge failures
        if (env.JOB_TYPE == "merge") {
          if (currentBuild.result == 'FAILURE') {
            // Send notification to rocketChat channel
            // Send merge build failure email notifications to the submitter
            sendNotifications(currentBuild.result, props["CHANNEL_NAME"])
          }
        }
      } // end finally block
} // end buildStages

def Build_Artifacts() {
  stage("Build Artifacts") {
    dir("$ROOTDIR/") {
      // Build Docker Images
      env.GOROOT = "/opt/go/go" + props["GO_VER"] + ".linux." + "$MARCH"
      GOPATH = "$WORKSPACE/gopath"
      env.PATH = "$GOROOT/bin:$GOPATH/bin:$PATH"
      fabBuildLibrary.cloneScm('fabric', 'master')
      fabBuildLibrary.fabBuildImages('fabric', 'docker')
      fabBuildLibrary.cloneScm('fabric-ca' ,'master')
      fabBuildLibrary.fabBuildImages('fabric-ca', 'docker')
    }
  }
}     

def Pull_Artifacts() {
  stage("Pull Artifacts") {
    dir("$ROOTDIR/$BASE_DIR") {
      // Pull Docker Images from nexus3
      fabBuildLibrary.pullDockerImages('2.0.0', 'nodeenv')
    }
  }
}

def Byfn_Eyfn_Tests() {
  stage("Byfn_Eyfn Tests") {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
      try {
        dir("$ROOTDIR/$PROJECT_DIR/fabric-samples") {
          fabBuildLibrary.cloneRepo 'fabric-samples'
          sh 'cd scripts/ && ./ciScript.sh ----byfn_eyfn_Tests'
        }
      }
      catch (err) {
        failure_stage = "Byfn_Eyfn_Tests"
        currentBuild.result = 'FAILURE'
        throw err
      }
    }
  }
}      

def UnitTests() {
  stage("UnitTests") {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
      try {
        dir("$ROOTDIR/$PROJECT_DIR/fabric") {
          // Run Unit-Tests
				  sh 'time make unit-test-clean peer-docker ccenv && ./unit-test/run.sh'
        }
      }
      catch (err) {
        failure_stage = "UnitTests"
        currentBuild.result = 'FAILURE'
        throw err
      }
    }
  }
}      