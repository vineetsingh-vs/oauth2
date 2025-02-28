pipeline {
    agent any

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
    }

    stages {
        stage('Notify GitHub Pending') {
            steps {
                script {
                    // Get the current commit SHA (will be valid after checkout, so this stage may need to run after checkout for an accurate SHA)
                    // Here we use a workaround by delaying status update until after checkout in a later stage.
                    echo "Setting build status to pending will occur after checkout."
                }
            }
        }

        stage('Print Build Info') {
            steps {
                script {
                    // WEBHOOK_BRANCH is injected by the Generic Webhook Trigger Plugin.
                    echo "WEBHOOK_BRANCH: ${env.WEBHOOK_BRANCH}"
                    // If WEBHOOK_BRANCH is set, remove the prefix; otherwise, it remains empty.
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    echo "Extracted branch from webhook: ${webhookBranch}"
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // Prefer the webhook-injected branch; if it's empty, fall back to 'master'
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchToCheckout = webhookBranch ? webhookBranch : 'master'
                    echo "Checking out branch: ${branchToCheckout}"
                    checkout([$class: 'GitSCM',
                              branches: [[name: branchToCheckout]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        stage('Notify GitHub Pending (Post-Checkout)') {
            steps {
                script {
                    def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    // Update GitHub status to "pending"
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh """
                        curl -H "Authorization: token ${GITHUB_TOKEN}" \
                             -d '{"state": "pending", "target_url": "${env.BUILD_URL}", "context": "CI Build", "description": "Build started"}' \
                             https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                        """
                    }
                }
            }
        }

        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchUsed = webhookBranch ? webhookBranch : 'master'
                    def sanitizedBranch = branchUsed.replace('/', '-')
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

                    // Determine effective branch from the webhook if available, or default to 'master'
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def effectiveBranch = webhookBranch ? webhookBranch : 'master'

                    // Decide to push automatically only for develop/master branches.
                    def shouldPush = (effectiveBranch in ['develop', 'master', 'origin/develop', 'origin/master'])

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
                def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                // Update GitHub status to "success"
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                    curl -H "Authorization: token ${GITHUB_TOKEN}" \
                         -d '{"state": "success", "target_url": "${env.BUILD_URL}", "context": "CI Build", "description": "Build succeeded"}' \
                         https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                    """
                }
            }
        }
        failure {
            script {
                def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                // Update GitHub status to "failure"
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                    curl -H "Authorization: token ${GITHUB_TOKEN}" \
                         -d '{"state": "failure", "target_url": "${env.BUILD_URL}", "context": "CI Build", "description": "Build failed"}' \
                         https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                    """
                }
            }
        }
        always {
            echo "Cleaning up build environment..."
        }
    }
}

