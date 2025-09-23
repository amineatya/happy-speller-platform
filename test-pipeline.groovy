pipeline {
  agent any
  tools {
    nodejs 'NodeJS-18' // This name must match your Jenkins configuration
  }
  stages {
    stage('Check Node') {
      steps {
        sh 'echo $PATH && which node && node -v && npm -v'
      }
    }
  }
}
