pipeline {
  agent any

  environment {
    // Replace with your Docker Hub repository details
    DOCKERHUB_REPO = 'maddiemoldrem/oauth_server'
  }

  stages {
    stage('Checkout') {
      steps {
        // Cloning the repository from GitHub
        checkout scm
      }
    }
    stage('Verify Dockerfile') {
      steps {
        script {
          // Check if the Dockerfile exists in the repository root
          if (fileExists('Dockerfile')) {
            echo "Dockerfile found."
          } else {
            error "Dockerfile not found! Failing build."
          }
        }
      }
    }
    stage('Build Docker Image') {
      steps {
        script {
          // Use the GIT_COMMIT environment variable as part of the tag; fallback to 'latest'
          def commitId = env.GIT_COMMIT ?: 'latest'
          echo "Building Docker image with tag: ${commitId}"
          sh "docker build -t ${DOCKERHUB_REPO}:${commitId} ."
        }
      }
    }
    stage('Push Docker Image') {
      steps {
        script {
          // Login to Docker Hub using credentials stored in Jenkins environment variables
          sh "docker login -u ${env.DOCKERHUB_USERNAME} -p ${env.DOCKERHUB_PASSWORD}"
          def commitId = env.GIT_COMMIT ?: 'latest'
          sh "docker push ${DOCKERHUB_REPO}:${commitId}"
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline completed."
    }
    failure {
      echo "Pipeline failed! Check the logs for errors."
    }
  }
}


