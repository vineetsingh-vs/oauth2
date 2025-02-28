pipeline {
    agent any

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
        GITHUB_TOKEN_ID = "maddie-PAT"
    }

    stages {
        stage('Print Parameters') {
            steps {

                echo "WEBHOOK_BRANCH: ${env.WEBHOOK_BRANCH}"
                echo "BRANCH_BUILD: ${params.BRANCH_BUILD}"
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // If WEBHOOK_BRANCH is set, remove the 'refs/heads/' prefix.
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    // Use webhookBranch if available; otherwise fallback to the Git parameter or default to 'master'
                    def branchToCheckout = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')

                    echo "Checkout: ${branchToCheckout}"

                    // Use your actual repository URL
                    checkout([$class: 'GitSCM',
                              branches: [[name: branchToCheckout]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        stage('Notify GitHub - Pending') {
                    steps {
                        script {
                            // 1) Get the commit SHA Jenkins is building
                            def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()

                            // 2) Use your personal access token to send a pending status
                            withCredentials([string(credentialsId: GITHUB_TOKEN_ID, variable: 'GITHUB_TOKEN')]) {
                                sh """
                                curl -H "Authorization: token \$GITHUB_TOKEN" \
                                     -d '{
                                       "state": "pending",
                                       "target_url": "${env.BUILD_URL}",
                                       "context": "CI Build",
                                       "description": "Build started"
                                     }' \
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
                    // Use the same branch logic for the tag
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def branchUsed = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
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

                            // Determine effective branch: prefer WEBHOOK_BRANCH if available
                            def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                            def effectiveBranch = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')

                            // Decide whether to push:
                            // Push if manually triggered OR if the branch is develop/master (or their origin forms)
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
                    def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    withCredentials([string(credentialsId: GITHUB_TOKEN_ID, variable: 'GITHUB_TOKEN')]) {
                        sh """
                        curl -H "Authorization: token \$GITHUB_TOKEN" \
                             -d '{
                               "state": "success",
                               "target_url": "${env.BUILD_URL}",
                               "context": "CI Build",
                               "description": "Build succeeded"
                             }' \
                             https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                        """
                    }
                }
            }
            failure {
                script {
                    def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    withCredentials([string(credentialsId: GITHUB_TOKEN_ID, variable: 'GITHUB_TOKEN')]) {
                        sh """
                        curl -H "Authorization: token \$GITHUB_TOKEN" \
                             -d '{
                               "state": "failure",
                               "target_url": "${env.BUILD_URL}",
                               "context": "CI Build",
                               "description": "Build failed"
                             }' \
                             https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                        """
                    }
                }
            }
            always {
                echo "Cleaning up..."
            }
        }
}




