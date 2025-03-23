/**
 * Author: Madeline Moldrem
 *
 * This Jenkins pipeline automates the complete build, infrastructure, and deployment process
 * for the OAuth2 server. The pipeline performs the following actions:
 *
 * 1. Sets an initial GitHub commit status to 'pending' to indicate the build is in progress.
 * 2. Checks out the code from GitHub based on provided branch parameters.
 * 3. Generates a unique Docker image tag using the commit hash and branch information.
 * 4. Builds the Docker image and conditionally pushes it to Docker Hub.
 * 5. Dynamically determines the target environment (UAT or Prod) based on the branch name
 *    or an explicit parameter.
 * 6. Executes Terraform commands (init, plan, apply) inside a Docker container using the
 *    appropriate variable file for UAT or production to manage AWS infrastructure.
 * 7. Deploys the new Docker image to the target Auto Scaling Group (ASG) by SSHing into each
 *    instance and executing docker-compose commands.
 * 8. Updates the GitHub commit status to SUCCESS or FAILURE depending on the final build result.
 *
 * Requirements:
 * - GitHub credentials with at least the "repo:status" scope.
 * - Jenkins plugins: GitHub Plugin, GitHub Commit Status Setter Plugin, etc.
 * - AWS CLI configured on Jenkins or available within the pipeline environment.
 * - AWS credentials stored securely in Jenkins Credentials (referenced as 'aws-access-key-id' and
 *   'aws-secret-access-key').
 * - SSH credentials (e.g., 'deployment-credentials') set up in Jenkins for accessing EC2 instances.
 * - Pre-existing AWS resources (Auto Scaling Groups, ALB, etc.) that match the Terraform configuration.
 */

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(daysToKeepStr: '14', numToKeepStr: '10'))
    }

    environment {
        DOCKER_REPO         = credentials('docker-repo')
        DOCKER_COMPOSE_FILE = "docker-compose.yml"
        GITHUB_REPO         = "vineetsingh-vs/oauth2"
        UAT_ASG_NAME        = credentials('uat-asg-name')
        PROD_ASG_NAME       = credentials('prod-asg-name')
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    stages {
        stage('Set GitHub Pending Status') {
            steps {
                script {
                    def pendingStatusParams = [
                        statusResultSource: [
                            $class: 'ConditionalStatusResultSource',
                            results: [
                                [$class: 'AnyBuildResult', message: 'Build in progress', state: 'PENDING']
                            ]
                        ]
                    ]
                    step([$class: 'GitHubCommitStatusSetter'] + pendingStatusParams)
                }
            }
        }
        stage('Checkout') {
            steps {
                script {
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\\/heads\\//, '') : ''
                    def branchToCheckout = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                    echo "Checking out branch: ${branchToCheckout}"
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: branchToCheckout]],
                        userRemoteConfigs: [[url: "https://github.com/${env.GITHUB_REPO}.git"]]
                    ])
                    env.BRANCH_NAME = branchToCheckout
                    echo "Checked out branch: ${branchToCheckout}"
                }
            }
        }
        stage('Set Unique Tag') {
            steps {
                script {
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\\/heads\\//, '') : ''
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
                    sh "docker build --no-cache -t ${env.IMAGE_TAG} ."
                    echo "Docker build completed."
                    def webhookBranch = env.WEBHOOK_BRANCH?.trim() ? env.WEBHOOK_BRANCH.replaceFirst(/^refs\\/heads\\//, '') : ''
                    def effectiveBranch = webhookBranch ? webhookBranch : (params.BRANCH_BUILD?.trim() ? params.BRANCH_BUILD : 'master')
                    def shouldPush = !webhookBranch || (effectiveBranch in ['develop', 'master', 'origin/develop', 'origin/master'])
                    if (shouldPush) {
                        echo "Pushing Docker image for branch: ${effectiveBranch}"
                        withCredentials([usernamePassword(credentialsId: 'maddie-docker', passwordVariable: 'DOCKER_HUB_PASS', usernameVariable: 'DOCKER_HUB_USER')]) {
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
        stage('Determine Target Environment') {
            steps {
                script {
                    def targetEnv = params.TARGET_ENV?.trim() ? params.TARGET_ENV.trim() : (env.BRANCH_NAME == 'master' ? 'prod' : 'uat')
                    env.TARGET_ENV_DYNAMIC = targetEnv
                    echo "Dynamic Target Environment: ${env.TARGET_ENV_DYNAMIC}"
                }
            }
        }
        stage('Terraform Init') {
            steps {
                script {
                    def tfVarFile = (env.TARGET_ENV_DYNAMIC == 'prod') ? "configs/prod.tfvars" : "configs/uat.tfvars"
                    echo "Using Terraform var file: ${tfVarFile}"
                    sh '''
                      docker run --rm \
                        -v "$WORKSPACE/terraform":/workspace \
                        -w /workspace \
                        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                        hashicorp/terraform:latest init
                    '''
                }
            }
        }
        stage('Terraform Plan') {
            steps {
                script {
                    def tfVarFile = (env.TARGET_ENV_DYNAMIC == 'prod') ? "configs/prod.tfvars" : "configs/uat.tfvars"
                    sh """
                      docker run --rm \
                        -v "$WORKSPACE/terraform":/workspace \
                        -w /workspace \
                        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                        hashicorp/terraform:latest plan -var-file='${tfVarFile}'
                    """
                }
            }
        }
        stage('Terraform Apply') {
            steps {
                script {
                    def tfVarFile = (env.TARGET_ENV_DYNAMIC == 'prod') ? "configs/prod.tfvars" : "configs/uat.tfvars"
                    if (env.TARGET_ENV_DYNAMIC == 'prod') {
                        input message: 'Approve Terraform Apply for Production?'
                    }
                    sh """
                      docker run --rm \
                        -v "$WORKSPACE/terraform":/workspace \
                        -w /workspace \
                        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                        hashicorp/terraform:latest apply -auto-approve -var-file='${tfVarFile}'
                    """
                }
            }
        }
        stage('Deploy') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'master'
                    branch 'origin/develop'
                    branch 'origin/master'
                }
            }
            steps {
                script {
                    def targetEnv = env.TARGET_ENV_DYNAMIC
                    echo "Deploying to target environment: ${targetEnv}"
                    def asgName = (targetEnv == 'prod') ? env.PROD_ASG_NAME : env.UAT_ASG_NAME
                    echo "Using ASG: ${asgName}"

                    // Delay to allow the ASG to register instances
                    echo "Waiting for instances to become available..."
                    sh "sleep 30"

                    def instanceIdsOutput = sh(script: """
                      aws autoscaling describe-auto-scaling-groups \\
                        --auto-scaling-group-names "uat-oauth-asg" \\
                        --query 'AutoScalingGroups[0].Instances[].InstanceId' \\
                        --output text \\
                        --region us-east-2
                    """, returnStdout: true).trim()

                    def instanceIds = instanceIdsOutput.tokenize()
                    echo "Found instances: ${instanceIds}"

                    for (instanceId in instanceIds) {
                        def publicIp = sh(script: """
                            aws ec2 describe-instances \\
                              --instance-ids "i-08542c205cf1eb594" \\
                              --query 'Reservations[0].Instances[0].PublicIpAddress' \\
                              --output text \\
                              --region us-east-2
                        """, returnStdout: true).trim()

                        echo "Deploying to instance ${instanceId} at ${publicIp}"
                        sshagent(['deployment-credentials']) {
                            sh """
                              ssh -o StrictHostKeyChecking=no ubuntu@${publicIp} '
                                  cd /home/ubuntu/deployment/ &&
                                  rm -rf * .[^.]* || true &&
                                  git clone --branch ${env.BRANCH_NAME} https://github.com/${env.GITHUB_REPO}.git . &&
                                  rm -f .env &&
                                  chmod +x variable-env.sh &&
                                  ./variable-env.sh &&
                                  export TARGET_ENV=${targetEnv} &&
                                  export IMAGE_TAG=${env.IMAGE_TAG} &&
                                  docker compose pull &&
                                  docker compose up -d --force-recreate
                              '
                            """
                        }
                    }
                }
            }
        }
        stage('Set GitHub Commit Status') {
            steps {
                script {
                    def status = currentBuild.currentResult == 'SUCCESS' ? 'SUCCESS' : 'FAILURE'
                    def message = currentBuild.currentResult == 'SUCCESS' ? 'Build completed successfully' : 'Build failed'
                    def finalStatusParams = [
                        statusResultSource: [
                            $class: 'ConditionalStatusResultSource',
                            results: [
                                [$class: 'AnyBuildResult', message: message, state: status]
                            ]
                        ]
                    ]
                    step([$class: 'GitHubCommitStatusSetter'] + finalStatusParams)
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
