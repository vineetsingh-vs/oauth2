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
                    sh "npm install"
                    sh "npm test"
                }
            }
        }
        stage('Build and Push Docker Image') {
            steps {
                script {
                    def imageTag = ""
                    if (params.BRANCH_BUILD == "develop" || params.BRANCH_BUILD == "master") {
                        // For develop and master, tag using just the build number.
                        imageTag = "${DOCKER_REPO}:${env.BUILD_NUMBER}"
                        echo "Building image for ${params.BRANCH_BUILD} branch with tag ${imageTag}"
                        sh "docker build -t ${imageTag} ."

                        // Log in and push automatically.
                        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                             passwordVariable: 'DOCKERHUB_PASSWORD',
                                                             usernameVariable: 'DOCKERHUB_USERNAME')]) {
                            sh "echo ${DOCKERHUB_PASSWORD} | docker login -u ${DOCKERHUB_USERNAME} --password-stdin"
                        }
                        sh "docker push ${imageTag}"
                    } else {
                        // For feature or other branches, include the branch name in the tag.
                        imageTag = "${DOCKER_REPO}:${params.BRANCH_BUILD}-${env.BUILD_NUMBER}"
                        echo "Building image for feature branch ${params.BRANCH_BUILD} with tag ${imageTag}"
                        sh "docker build -t ${imageTag} ."

                        // Pause for manual approval before pushing.
                        input message: "Do you want to push the image ${imageTag} to Docker Hub?", ok: "Push"

                        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                             passwordVariable: 'DOCKERHUB_PASSWORD',
                                                             usernameVariable: 'DOCKERHUB_USERNAME')]) {
                            sh "echo ${DOCKERHUB_PASSWORD} | docker login -u ${DOCKERHUB_USERNAME} --password-stdin"
                        }
                        sh "docker push ${imageTag}"
                    }

                    // Record the image tag for later use if needed.
                    env.DOCKER_IMAGE = imageTag
                }
            }
        }
        // Note: Deployment stage is commented out for now.
    }
    post {
        always {
            echo "Cleaning up build environment..."
            // Optionally, add cleanup commands, e.g.:
            // sh "docker system prune -f"
        }
    }
}