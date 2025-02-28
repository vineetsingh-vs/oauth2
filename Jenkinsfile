pipeline {
    agent any

    parameters {
        // Git Parameter for manual selection (if needed)
        gitParameter(
            name: 'BRANCH_BUILD',
            type: 'PT_BRANCH', // Use PT_BRANCH to list branches
            defaultValue: 'origin/master',
            description: 'Select branch to build',
            useRepository: 'https://github.com/vineetsingh-vs/oauth2.git',
            branchFilter: '.*',
            sortMode: 'ASCENDING',
            quickFilterEnabled: true
        )
        booleanParam(name: 'FORCE_PUSH', defaultValue: false, description: 'Force push Docker image on manual build')
    }

    environment {
        DOCKER_REPO = "maddiemoldrem/oauth_server"
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
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
                    // If WEBHOOK_BRANCH is set, remove the 'refs/heads/' prefix.
                    def webhookBranch = params.WEBHOOK_BRANCH?.trim() ? params.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    echo "WEBHOOK_BRANCH: ${params}"
                    // Use webhookBranch if available; otherwise fallback to the Git parameter or default to 'master'
                    def branchToCheckout = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')

                    // Use your actual repository URL
                    checkout([$class: 'GitSCM',
                              branches: [[name: branchToCheckout]],
                              userRemoteConfigs: [[url: 'https://github.com/vineetsingh-vs/oauth2.git']]
                    ])
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }

        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    // Use the same branch logic for the tag
                    def webhookBranch = params.WEBHOOK_BRANCH?.trim() ? params.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
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

                    def webhookBranch = params.WEBHOOK_BRANCH?.trim() ? params.WEBHOOK_BRANCH.replaceFirst(/^refs\/heads\//, '') : ''
                    def effectiveBranch = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
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







