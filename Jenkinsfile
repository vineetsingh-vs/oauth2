pipeline {
    agent any
    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
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
        stage('Build and Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag ${env.IMAGE_TAG}"
                    sh "docker build -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."

                        withCredentials([usernamePassword(credentialsId: 'maddie-docker',
                                                      passwordVariable: 'DOCKER_HUB_PASS',
                                                      usernameVariable: 'DOCKER_HUB_USER')]) {
                            echo "Logging into Docker Hub..."
                            sh "echo ${DOCKER_HUB_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin"
                            echo "Docker Hub login succeeded."
                        }

                    // Current implementation: Auto-push for any branch.
                    echo "Auto-pushing image ${env.IMAGE_TAG} for ${params.BRANCH_BUILD} branch."
                    sh "docker push ${env.IMAGE_TAG}"

                    // Uncomment the block below later to differentiate between master/develop and feature branches.
                    /*
                    if (params.BRANCH_BUILD == "develop" || params.BRANCH_BUILD == "master") {
                        echo "Auto-pushing image ${env.IMAGE_TAG} for ${params.BRANCH_BUILD} branch."
                        sh "docker push ${env.IMAGE_TAG}"
                    } else {
                        echo "Image built for feature branch: ${env.IMAGE_TAG}"
                        input message: "Do you want to push the image ${env.IMAGE_TAG} to Docker Hub?", ok: "Push"
                        sh "docker push ${env.IMAGE_TAG}"
                    }
                    */
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





