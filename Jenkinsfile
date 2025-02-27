pipeline {
    agent any

    parameters {
        // Branch name to build (populated automatically by a webhook via Generic Webhook Trigger, or manually)
        string(name: 'BRANCH_BUILD', defaultValue: '', description: 'Branch to build')
        // When set to true during a manual build, the Docker image will be pushed regardless of branch
        booleanParam(name: 'FORCE_PUSH', defaultValue: false, description: 'Force push Docker image on manual build')
    }

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
    }

    stages {
        stage('Notify Pending') {
            steps {
                // Notify GitHub that the build has started
                githubNotify context: 'Jenkins Build', description: 'Build started', status: 'PENDING'
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // Check out the branch from BRANCH_BUILD (populated via webhook or manual input)
                    checkout([$class: 'GitSCM',
                              branches: [[name: params.BRANCH_BUILD]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${params.BRANCH_BUILD}"
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
                    // Get the short commit hash from the repository
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    // Sanitize the branch name: replace any "/" with "-"
                    def sanitizedBranch = params.BRANCH_BUILD.replace('/', '-')
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

                    // Determine whether to push:
                    // 1) If FORCE_PUSH is true (manual build override),
                    // 2) OR if the branch is develop or master (automatic build).
                    if (params.FORCE_PUSH || params.BRANCH_BUILD in ['develop', 'master']) {
                        echo "Pushing Docker image for branch: ${params.BRANCH_BUILD}"
                        withCredentials([usernamePassword(credentialsId: 'maddie-docker',
                                                          passwordVariable: 'DOCKER_HUB_PASS',
                                                          usernameVariable: 'DOCKER_HUB_USER')]) {
                            echo "Logging into Docker Hub..."
                            sh "echo ${DOCKER_HUB_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin"
                            echo "Docker Hub login succeeded."
                        }
                        sh "docker push ${env.IMAGE_TAG}"
                    } else {
                        echo "Skipping Docker push for branch: ${params.BRANCH_BUILD}"
                    }
                }
            }
        }
    }

    post {
        success {
            // Notify GitHub that the build succeeded
            githubNotify context: 'Jenkins Build', description: 'Build succeeded', status: 'SUCCESS'
        }
        failure {
            // Notify GitHub that the build failed
            githubNotify context: 'Jenkins Build', description: 'Build failed', status: 'FAILURE'
        }
        always {
            echo "Cleaning up build environment..."
            // Optionally, add cleanup commands here, e.g.:
            // sh "docker system prune -f"
        }
    }
}
