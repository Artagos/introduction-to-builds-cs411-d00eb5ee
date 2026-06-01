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
        stage('Deploy Kubernetes files') {
            steps {
                withCredentials([string(credentialsId: 'kub', variable: 'TOKEN')]) {
                    sh 'kubectl --server=https://kubernetes:6443 --insecure-skip-tls-verify=true --token=$TOKEN apply -f pod.yaml'
                }
            }
        }
    }
}
