pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                script {
                    sh 'docker build -t ttl.sh/artagos:2h .'
                }
            }
        }
        stage('Push') {
            steps {
                script {
                    sh 'docker push ttl.sh/artagos:2h'
                }
            }
        }
        stage('Deploy to docker VM') {
            agent { label 'docker' }
            steps {
                script {
                    sh '''
                      docker pull ttl.sh/artagos:2h
                      docker rm -f artagos || true
                      docker run -d --name artagos -p 4444:4444 ttl.sh/artagos:2h
                    '''
                }
            }
        }
    }
}
