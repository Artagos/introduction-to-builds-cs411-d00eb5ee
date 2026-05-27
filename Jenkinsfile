pipeline {
    agent any

    tools {
       go "1.24.1"
    }
    stages {
        stage('Build') {
            steps {
                sh "go build main.go"
            }
        }
    stage('Deploy') {
        steps {
            withCredentials([sshUserPrivateKey(
                credentialsId: 'target-ssh',
                keyFileVariable: 'SSH_KEY',
                usernameVariable: 'laborant'
            )]) {
                sh '''
                # 1. Trust the target host
                mkdir -p ~/.ssh
                ssh-keyscan -H target >> ~/.ssh/known_hosts

                # 2. $SSH_KEY points to the temporary file path automatically
                scp -i "$SSH_KEY" main laborant@target:~
            ''' 
            }
            
        }
    }
    }
}
