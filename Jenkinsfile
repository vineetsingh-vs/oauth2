pipeline {
    agent any
    environment {
        // Define your Docker Hub repository base
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        // The docker-compose file location (if needed)
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
    }
    stages {
        stage('Checkout') {
            steps {
                script {
                    // Use the Git Parameter to dynamically check out the selected branch.
                    checkout([$class: 'GitSCM',
                              branches: [[name: params.BRANCH_BUILD]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                             ])
                }
            }
        }
        stage('Set Unique Tag') {
            steps {
                script {
                    // Get the short commit hash from the repository
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    // For develop/master, use a tag format with branch, build number, and commit hash
                    if (params.BRANCH_BUILD == "develop" || params.BRANCH_BUILD == "master") {
                        env.IMAGE_TAG = "${DOCKER_REPO}:${params.BRANCH_BUILD}-${env.BUILD_NUMBER}-${commitHash}"
                    } else {
                        env.IMAGE_TAG = "${DOCKER_REPO}:${params.BRANCH_BUILD}-${env.BUILD_NUMBER}-${commitHash}"
                    }
                    echo "Unique Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }
        stage('Build Docker Images with Docker Compose') {
            steps {
                script {
                    // Build docker images using docker-compose (if needed)
                    sh "docker-compose -f ${DOCKER_COMPOSE_FILE} build"
                }
            }
        }
        stage('Run Tests') {
            steps {
                script {
                    // Install dependencies and run tests for your Node.js/Passport OAuth server.
                    sh "npm install"
                    sh "npm test"
                }
            }
        }
        stage('Build and Push Docker Image') {
            steps {
                script {
                    // Build the Docker image using the unique tag
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."

                    // Log in to Docker Hub using Jenkins credentials
                    withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                      passwordVariable: 'DOCKERHUB_PASSWORD',
                                                      usernameVariable: 'DOCKERHUB_USERNAME')]) {
                        sh "echo ${DOCKERHUB_PASSWORD} | docker login -u ${DOCKERHUB_USERNAME} --password-stdin"
                    }

                    if (params.BRANCH_BUILD == "develop" || params.BRANCH_BUILD == "master") {
                        // For develop and master, push automatically.
                        echo "Auto-pushing image ${env.IMAGE_TAG} for ${params.BRANCH_BUILD} branch."
                        sh "docker push ${env.IMAGE_TAG}"
                    } else {
                        // For feature or other branches, prompt for manual approval before pushing.
//                         echo "Image built for feature branch: ${env.IMAGE_TAG}"
//                         input message: "Do you want to push the image ${env.IMAGE_TAG} to Docker Hub?", ok: "Push"
//                         sh "docker push ${env.IMAGE_TAG}"
                        echo "Auto-pushing image ${env.IMAGE_TAG} for ${params.BRANCH_BUILD} branch."
                        sh "docker push ${env.IMAGE_TAG}"
                    }
                }
            }
        }
        // (Deployment stage can be added here later if needed)
    }
    post {
        always {
            echo "Cleaning up build environment..."
            // Optionally, add cleanup commands, e.g.:
            // sh "docker system prune -f"
        }
    }
}
