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
                withCredentials([sshUserPrivateKey(credentialsId: 'target_ssh', keyFileVariable: 'DOCKER_SSH_KEY')]) {
                    sh '''
                        ssh -i $DOCKER_SSH_KEY -o StrictHostKeyChecking=no laborant@docker \
                            "docker pull ttl.sh/artagos:2h && \
                             docker stop go-server || true && \
                             docker rm go-server || true && \
                             docker run -d -p 4444:4444 --name go-server ttl.sh/artagos:2h"
                    '''
                }
            }
        }
    }
}
