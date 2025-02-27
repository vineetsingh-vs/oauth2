pipeline {
    agent any

    parameters {
        // This parameter is automatically populated by the webhook,
        // but you can also override it manually.
        string(name: 'BRANCH_BUILD', defaultValue: '', description: 'Branch to build (populated by webhook or manually)')
        // When true, forces Docker image push on manual build.
        booleanParam(name: 'FORCE_PUSH', defaultValue: false, description: 'Force push Docker image on manual build')
    }

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        // Your GitHub repository in the format "owner/repo"
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
                    // Use the branch from BRANCH_BUILD; default to 'master' if empty.
                    def branchToCheckout = params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master'
                    checkout([$class: 'GitSCM',
                              branches: [[name: branchToCheckout]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        // Other stages: verifying Docker, building images, running tests, etc.
        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    // Replace any "/" with "-" in branch name for a valid Docker tag.
                    def sanitizedBranch = (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master').replace('/', '-')
                    env.IMAGE_TAG = "${DOCKER_REPO}:${sanitizedBranch}-${env.BUILD_NUMBER}-${commitHash}"
                    echo "Unique Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }

        // Example stage: Build Docker image and conditionally push.
        stage('Build and (Conditionally) Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."

                    def effectiveBranch = params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master'
                    // Only push if FORCE_PUSH is true OR if branch is develop or master.
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

