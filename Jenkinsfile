pipeline {
    agent any

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
        // Optionally set a default commit SHA (if not provided via webhook)
        GIT_COMMIT_SHA = ""
    }

    stages {
        stage('Notify Build Started') {
            steps {
                script {
                    // Optionally, if your webhook payload includes the commit SHA,
                    // you could set GIT_COMMIT_SHA from that payload.
                    // Otherwise, after checkout you can use the full commit SHA.
                    //
                    // For now, send a "pending" status using the commit hash you will resolve later.
                    echo "PENDING: ${env.GIT_COMMIT_SHA}"
                    githubNotify context: 'Jenkins CI', status: 'PENDING', message: 'Build started', commitSha: "${env.GIT_COMMIT_SHA}"
                }
            }
        }

        stage('Print Parameters') {
            steps {
                echo "WEBHOOK_BRANCH: ${env.WEBHOOK_BRANCH}"
                echo "BRANCH_BUILD: ${params.BRANCH_BUILD}"
            }
        }

        stage('Checkout') {
            steps {
                script {
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchToCheckout = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                    echo "Checkout: ${branchToCheckout}"

                    checkout([$class: 'GitSCM',
                              branches: [[name: branchToCheckout]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"

                    // Capture the full commit hash for GitHub notifications
                    env.GIT_COMMIT_SHA = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                }
            }
        }

        stage('Set Unique Tag') {
            steps {
                script {
                    // Now that we have the full commit SHA, you can use its short version for tagging.
                    def commitHashShort = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchUsed = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                    def sanitizedBranch = branchUsed.replace('/', '-')
                    env.IMAGE_TAG = "${DOCKER_REPO}:${sanitizedBranch}-${env.BUILD_NUMBER}-${commitHashShort}"
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

                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def effectiveBranch = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
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
    }

    post {
        success {
            script {
                // Notify GitHub that the build was successful.
                githubNotify context: 'Jenkins CI', status: 'SUCCESS', message: 'Build succeeded', commitSha: "${env.GIT_COMMIT_SHA}"
            }
        }
        failure {
            script {
                // Notify GitHub that the build failed.
                githubNotify context: 'Jenkins CI', status: 'FAILURE', message: 'Build failed', commitSha: "${env.GIT_COMMIT_SHA}"
            }
        }
        always {
            echo "Cleaning up build environment..."
        }
    }
}
