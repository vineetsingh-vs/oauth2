pipeline {
    agent any

    parameters {
        // Branch to build – populated by a webhook (Generic Webhook Trigger) or manually entered.
        // When true, force the Docker push regardless of branch.
        booleanParam(name: 'FORCE_PUSH', defaultValue: false, description: 'Force push Docker image on manual build')
    }

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        // Set your GitHub repository in the form "owner/repo"
        GITHUB_REPO = "vineetsingh-vs/oauth2"
    }

    stages {
        stage('Print Parameters') {
            steps {
                echo "BRANCH_BUILD: ${params.BRANCH_BUILD}"
                echo "FORCE_PUSH: ${params.FORCE_PUSH}"
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // Use the branch provided by BRANCH_BUILD; if empty, default to 'master'
                    def branchToCheckout = params.BRANCH_BUILD ? params.BRANCH_BUILD : 'master'
                    checkout([$class: 'GitSCM',
                              branches: [[name: branchToCheckout]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        stage('Notify Pending') {
            steps {
                script {
                    // Get the commit SHA for the current build.
                    def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    // Update GitHub commit status to pending.
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh """
                        curl -H "Authorization: token ${GITHUB_TOKEN}" \
                             -d '{"state": "pending", "context": "Jenkins Build", "description": "Build started"}' \
                             https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                        """
                    }
                }
            }
        }

        stage('Verify Docker Installation') {
            steps {
                echo "Verifying Docker installation..."
                sh 'docker --version'
            }
        }

        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    // Sanitize branch: replace any "/" with "-"
                    def sanitizedBranch = (params.BRANCH_BUILD ? params.BRANCH_BUILD : 'master').replace('/', '-')
                    env.IMAGE_TAG = "${DOCKER_REPO}:${sanitizedBranch}-${env.BUILD_NUMBER}-${commitHash}"
                    echo "Unique Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build Docker Images with Docker Compose') {
            steps {
                script {
                    echo "Starting docker-compose build..."
                    sh "docker-compose -f ${DOCKER_COMPOSE_FILE} build"
                    echo "docker-compose build completed."
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    echo "Running npm install and tests..."
                    sh "npm install"
                    sh "npm test"
                    echo "Tests completed."
                }
            }
        }

        stage('Build and (Conditionally) Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."

                    // Determine if we should push:
                    // Push automatically if FORCE_PUSH is true OR branch is develop/master.
                    def effectiveBranch = params.BRANCH_BUILD ? params.BRANCH_BUILD : 'master'
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
        success {
            script {
                def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                withCredentials([string(credentialsId: 'maddie-PAT', variable: 'GITHUB_TOKEN')]) {
                    sh """
                    curl -H "Authorization: token ${GITHUB_TOKEN}" \
                         -d '{"state": "success", "context": "Jenkins Build", "description": "Build succeeded"}' \
                         https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                    """
                }
            }
        }
        failure {
            script {
                def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                    curl -H "Authorization: token ${GITHUB_TOKEN}" \
                         -d '{"state": "failure", "context": "Jenkins Build", "description": "Build failed"}' \
                         https://api.github.com/repos/${env.GITHUB_REPO}/statuses/${commitSha}
                    """
                }
            }
        }
        always {
            echo "Cleaning up build environment..."
            // Optionally, add cleanup commands here, for example:
            // sh "docker system prune -f"
        }
    }
}
