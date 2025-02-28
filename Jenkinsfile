pipeline {
    agent any

    parameters {

           gitParameter(
                    name: 'BRANCH_BUILD',
                    type: 'PT_BRANCH',                 // Must specify a valid type: PT_BRANCH, PT_TAG, etc.
                    defaultValue: 'origin/master',
                    description: 'Select branch to build',
                    useRepository: 'https://github.com/vineetsingh-vs/oauth2.git',
                    branchFilter: '.*',
                    sortMode: 'ASCENDING',
                    quickFilterEnabled: true
                )
        // Remove the manual BRANCH_BUILD parameter to let the webhook trigger inject it.
        booleanParam(name: 'FORCE_PUSH', defaultValue: false, description: 'Force push Docker image on manual build')
    }

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
    }

    stages {
        stage('Print Parameters') {
            steps {
                // This should show the value injected by the webhook.
                echo "WEBHOOK_BUILD: ${params.WEBHOOK_BRANCH}"
                echo "FORCE_PUSH: ${params.FORCE_PUSH}"
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // If WEBHOOK_BRANCH is set, use that; otherwise fall back to BRANCH_BUILD
                           def branchToCheckout = params.WEBHOOK_BRANCH?.trim() ? params.WEBHOOK_BRANCH
                                                          : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                           checkout([$class: 'GitSCM',
                                              branches: [[name: branchToCheckout]],
                                              userRemoteConfigs: [[url: 'https://github.com/your/repo.git']]
                                    ])
                           echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def sanitizedBranch = (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master').replace('/', '-')
                    env.IMAGE_TAG = "${DOCKER_REPO}:${sanitizedBranch}-${env.BUILD_NUMBER}-${commitHash}"
                    echo "Unique Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build and (Conditionally) Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."

                    def effectiveBranch = params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master'
                    def shouldPush = params.FORCE_PUSH || (effectiveBranch in ['develop', 'master'])
                    if (shouldPush) {
                        echo "Pushing Docker image for branch: ${effectiveBranch}"
                        withCredentials([usernamePassword(credentialsId: 'maddie-docker',
                                                          passwordVariable: 'DOCKER_HUB_PASS',
                                                          usernameVariable: 'DOCKER_HUB_USER')]) {
                            echo "Logging into Docker Hub..."
                            sh "echo ${DOCKER_HUB_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin"
                            echo "Docker Hub login succeeded."
                        }
                        sh "docker push ${env.IMAGE_TAG}"
                    } else {
                        echo "Skipping Docker push for branch: ${effectiveBranch}"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning up build environment..."
        }
    }
}



