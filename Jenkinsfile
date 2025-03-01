/**
 * Author: Madeline Moldrem
 *
 * This Jenkins pipeline automates the build process for the OAuth2 server.
 * It performs the following actions:
 *   - Sets an initial GitHub commit status to 'pending' to indicate the build is in progress.
 *   - Checks out the code from GitHub based on the provided branch parameters.
 *   - Generates a unique Docker image tag using the commit hash and branch information.
 *   - Runs a pre-build docker-compose test (with or without --no-cache, based on a parameter)
 *     to ensure the service starts successfully.
 *   - Builds the Docker image and conditionally pushes it to Docker Hub.
 *   - Updates the GitHub commit status to SUCCESS or FAILURE depending on the final build result.
 */
pipeline {
    agent any

    parameters {
        // Set this to true to force a no-cache build (slower, but always fresh)
        booleanParam(name: 'NO_CACHE', defaultValue: false, description: 'Force no-cache build for docker-compose pre-test')
    }

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
        // Enable BuildKit for improved performance.
        DOCKER_BUILDKIT = "1"
        COMPOSE_DOCKER_CLI_BUILD = "1"
    }

    stages {
        // Stage 1: Set GitHub Pending Status.
        stage('Set GitHub Pending Status') {
            steps {
                script {
                    def pendingStatusParams = [
                        statusResultSource: [
                            $class: 'ConditionalStatusResultSource',
                            results: [
                                [$class: 'AnyBuildResult', message: 'Build in progress', state: 'PENDING']
                            ]
                        ]
                    ]
                    step([$class: 'GitHubCommitStatusSetter'] + pendingStatusParams)
                }
            }
        }

        // Stage 2: Checkout Code from GitHub.
        stage('Checkout') {
            steps {
                script {
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchToCheckout = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                    echo "Checking out branch: ${branchToCheckout}"
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: branchToCheckout]],
                        userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        // Stage 3: Set Unique Docker Image Tag.
        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchUsed = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                    def sanitizedBranch = branchUsed.replace('/', '-')
                    env.IMAGE_TAG = "${DOCKER_REPO}:${sanitizedBranch}-${env.BUILD_NUMBER}-${commitHash}"
                    echo "Unique Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }

        // Stage 4: Docker Compose Pre-Test.
        stage('Docker Compose Pre-Test') {
            steps {
                script {
                    // Use no-cache flag if the parameter is enabled.
                    def buildCommand = params.NO_CACHE ? "docker-compose build --no-cache" : "docker-compose build"
                    echo "Building docker-compose services with command: ${buildCommand}"
                    sh "${buildCommand}"

                    echo "Starting docker-compose services in detached mode..."
                    sh "docker-compose up -d"

                    // Wait for services to initialize.
                    echo "Waiting for services to initialize..."
                    sleep 30

                    // Check the health status of the 'oauth' service.
                    def oauthContainerId = sh(script: "docker-compose ps -q oauth", returnStdout: true).trim()
                    if (oauthContainerId == "") {
                        error "OAuth container not found."
                    }

                    def healthStatus = sh(script: "docker inspect --format='{{.State.Health.Status}}' ${oauthContainerId}", returnStdout: true).trim()
                    echo "OAuth container health status: ${healthStatus}"

                    if (healthStatus != "healthy") {
                        // Clean up containers before failing.
                        sh "docker-compose down"
                        error "Pre-test failed: OAuth container is not healthy (status: ${healthStatus})"
                    }

                    echo "Pre-test passed: OAuth container is healthy."

                    // Clean up the docker-compose services.
                    sh "docker-compose down"
                }
            }
        }

        // Stage 5: Build Docker Image and Conditionally Push.
        stage('Build and (Conditionally) Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."

                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def effectiveBranch = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')

                    // Determine if the image should be pushed.
                    def shouldPush = !webhookBranch || (effectiveBranch in ['develop', 'master', 'origin/develop', 'origin/master'])
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

        // Stage 6: Update GitHub Commit Status.
        stage('Set GitHub Commit Status') {
            steps {
                script {
                    def status = currentBuild.currentResult == 'SUCCESS' ? 'SUCCESS' : 'FAILURE'
                    def message = currentBuild.currentResult == 'SUCCESS' ? 'Build completed successfully' : 'Build failed'

                    def finalStatusParams = [
                        statusResultSource: [
                            $class: 'ConditionalStatusResultSource',
                            results: [
                                [$class: 'AnyBuildResult', message: message, state: status]
                            ]
                        ]
                    ]
                    step([$class: 'GitHubCommitStatusSetter'] + finalStatusParams)
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
