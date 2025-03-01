/**
 * Author: Madeline Moldrem
 *
 * This Jenkins pipeline automates the build process for the OAuth2 server.
 * It performs the following actions:
 *   - Sets an initial GitHub commit status to 'pending' to indicate the build is in progress.
 *   - Checks out the code from GitHub based on the provided branch parameters.
 *   - Generates a unique Docker image tag using the commit hash and branch information.
 *   - Runs a pre-build docker-compose test (with --no-cache and --abort-on-container-exit)
 *     to ensure the service starts successfully.
 *   - Builds the Docker image and conditionally pushes it to Docker Hub.
 *   - Updates the GitHub commit status to SUCCESS or FAILURE depending on the final build result.
 */

pipeline {
    agent any

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
    }

    stages {
        // Stage 1: Immediately set a pending status on GitHub to indicate the build is in progress.
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

        // Stage 2: Checkout the code from GitHub.
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

        // Stage 3: Set a unique Docker image tag based on commit hash and branch.
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

        // Stage 4: Pre-Build Docker Compose Validation
        stage('Docker Compose Pre-Test') {
            steps {
                script {
                    echo "Running docker-compose build with no-cache..."
                    // Build the docker-compose services with no cache.
                    sh "docker-compose build --no-cache"

                    echo "Running docker-compose up with abort-on-container-exit..."
                    // Run the containers. This command will exit if any container fails.
                    sh "docker-compose up --abort-on-container-exit"

                    echo "Bringing down docker-compose services..."
                    // Ensure the containers are stopped after the test.
                    sh "docker-compose down"
                }
            }
        }

        // Stage 5: Build the Docker image and push it conditionally.
        stage('Build and (Conditionally) Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."

                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def effectiveBranch = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')

                    // Push if triggered manually or if branch is develop/master (or their origin forms).
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

        // Stage 6: Update the GitHub commit status with the final result.
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
