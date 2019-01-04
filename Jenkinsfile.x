// Copyright IBM Corp All Rights Reserved
//
// SPDX-License-Identifier: Apache-2.0
//
timeout(60) {
node ('hyp-x') { // trigger build on x86_64 node
 timestamps {
    try {
     def ROOTDIR = pwd() // workspace dir (/w/workspace/<job_name>)
     env.PROJECT_DIR = "gopath/src/github.com/hyperledger"
     env.PROJECT = "fabric-baseimage"
     def nodeHome = tool 'nodejs-8.11.3'
     env.ARCH = "amd64"
     env.GOPATH = "$WORKSPACE/gopath"
     env.GO_VER = sh(returnStdout: true, script: 'curl -O https://raw.githubusercontent.com/hyperledger/fabric-baseimage/master/scripts/common/setup.sh && cat setup.sh | grep "GO_VER=" | cut -d "=" -f2').trim()
     env.GOROOT = "/opt/go/go${GO_VER}.linux.${ARCH}"
     env.PATH = "$GOROOT/bin:$GOPATH/bin:~/npm/bin:/home/jenkins/.nvm/versions/node/v${nodeHome}/bin:$PATH"
     def jobname = sh(returnStdout: true, script: 'echo ${JOB_NAME} | grep -q "verify" && echo patchset || echo merge').trim()
     def failure_stage = "none"
	// delete working directory
	deleteDir()
      stage("Fetch Patchset") { // fetch gerrit refspec on latest commit
          try {
             if (jobname == "patchset")  {
                   println "$GERRIT_REFSPEC"
                   println "$GERRIT_BRANCH"
                   checkout([
                       $class: 'GitSCM',
                       branches: [[name: '$GERRIT_REFSPEC']],
                       extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: '$BASE_DIR'], [$class: 'CheckoutOption', timeout: 10]],
                       userRemoteConfigs: [[credentialsId: 'hyperledger-jobbuilder', name: 'origin', refspec: '$GERRIT_REFSPEC:$GERRIT_REFSPEC', url: '$GIT_BASE']]])
              } else {
                   // Clone fabric-baseimage on merge
                   println "Clone $PROJECT repository"
                   checkout([
                       $class: 'GitSCM',
                       branches: [[name: 'refs/heads/$GERRIT_BRANCH']],
                       extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: '$BASE_DIR']],
                       userRemoteConfigs: [[credentialsId: 'hyperledger-jobbuilder', name: 'origin', refspec: '+refs/heads/$GERRIT_BRANCH:refs/remotes/origin/$GERRIT_BRANCH', url: '$GIT_BASE']]])
              }
              dir("${ROOTDIR}/$PROJECT_DIR/$PROJECT") {
              sh '''
                 # Print last two commit details
                 echo
                 git log -n2 --pretty=oneline --abbrev-commit
                 echo
              '''
              }
           }
            catch (err) {
                failure_stage = "Fetch patchset"
                currentBuild.result = 'FAILURE'
                throw err
			}
		}

     // clean environment and get env data
	stage("Clean Environment - Get Env Info") {
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
				dir("${ROOTDIR}/$PROJECT_DIR/fabric-baseimage/scripts/Jenkins_Scripts/") {
			    sh './CI_Script.sh --clean_Environment --env_Info'
			}
			}
			catch (err) {
			    failure_stage = "Clean Environment - Get Env Info"
			    currentBuild.result = 'FAILURE'
			    throw err
			}
		}
	}

	// Build baseimages
	stage("Build baseimages") {
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
				dir("${ROOTDIR}/$PROJECT_DIR/fabric-baseimage/") {
				        sh '''
				        # Build baseimages
					make docker
				'''
				}
			}
			catch (err) {
			    failure_stage = "Build baseimages"
			    currentBuild.result = 'FAILURE'
	                    throw err
			}
		}
	}

	// Build third-party images
	stage("Build thirdpartyimages") {
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
				dir("${ROOTDIR}/$PROJECT_DIR/fabric-baseimage/") {
				        sh '''
				        # Build baseimages
					make dependent-images
				'''
				}
			}
			catch (err) {
			    failure_stage = "Build thirdpartyimages"
			    currentBuild.result = 'FAILURE'
	                    throw err
			}
		}
	}

if (env.JOB_NAME == "fabric-baseimage-merge-x86_64") {
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
		        // Clone fabric and Build Docker Images
			fabricBuild()
			// Clone fabric-ca and Build Docker Images
			fabricCABuild()
			// Run byfn-eyfn
			byfneyfnTests()
			// Run unitTests
			unitTests()
		}
}

	} finally {
		if (env.JOB_NAME == "fabric-baseimage-merge-x86_64") {
			if (currentBuild.result == 'FAILURE') { // Other values: SUCCESS, UNSTABLE
				rocketSend message: "Build Notification - STATUS: *${currentBuild.result}* - BRANCH: *${env.GERRIT_BRANCH}* - PROJECT: *${env.PROJECT}* - BUILD_URL:  (<${env.BUILD_URL}|Open>)"
			}
		}
	} // finally block end here
  } // timestamps end here
} // node block end here
} // timeout block end here

def fabricBuild() {
//  Fabric
	stage("Build fabric Images") {
	def ROOTDIR = pwd()
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
				dir("${ROOTDIR}/$PROJECT_DIR") {
				sh '''
					# Clone fabric repository
					git clone --single-branch -b $GERRIT_BRANCH --depth 2 git://cloud.hyperledger.org/mirror/fabric
					echo -e "\033[32m cloned fabric repository" "\033[0m"
					cd fabric
					# Print last two commits
					echo
					git log -n2 --pretty=oneline --abbrev-commit
					echo
					# Build fabric Docker Images
					make docker
				'''
				}
			}
			catch (err) {
				failure_stage = "Build fabric Images"
				currentBuild.result = 'FAILURE'
				throw err
			}
		}
	}
}

def fabricCABuild() {
//  Fabric-ca
	stage("Build fabric-ca Images") {
	def ROOTDIR = pwd()
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
				dir("${ROOTDIR}/$PROJECT_DIR") {
				sh '''
					# Clone fabric-ca repository
					git clone --single-branch -b $GERRIT_BRANCH --depth 2 git://cloud.hyperledger.org/mirror/fabric-ca
					echo -e "\033[32m cloned fabric repository" "\033[0m"
					cd fabric-ca
					# Print last two commits
					echo
					git log -n2 --pretty=oneline --abbrev-commit
					echo
					# Build fabric-ca Docker Images
					make docker-fabric-ca
				'''
				}
			}
			catch (err) {
				failure_stage = "Build fabric-ca Images"
				currentBuild.result = 'FAILURE'
				throw err
			}
		}
	}
}

def byfneyfnTests() {
// byfn_eyfn tests (default, custom channel, couchdb, nodejs chaincode))
	stage("Run byfn_eyfn Tests") {
	def ROOTDIR = pwd()
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
			        dir("${ROOTDIR}/$PROJECT_DIR/fabric-baseimage/scripts/Jenkins_Scripts/") {
				sh './CI_Script.sh --byfn_eyfn_Tests'
				}
		        }
			catch (err) {
				failure_stage = "Run byfn_eyfn Tests"
				currentBuild.result = 'FAILURE'
				throw err
			}
		}
	}
}

def unitTests() {
// unit-tests
	stage("UnitTests") {
	def ROOTDIR = pwd()
		wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
			try {
				dir("${ROOTDIR}/$PROJECT_DIR/fabric-ca") {
					// Run Unit-Tests
					sh 'make ci-tests'
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
