pipeline {
    agent any
    tools{
        go '1.24.1'
    }

    stages {
        stage('Build') {
            steps {
                    sh "CGO_ENABLED=0 go build -o main main.go"
            }
        }
        stage('Deploy') {
            steps {
                sshagent(['ssh-key']) {
                    sh 'scp -o StrictHostKeyChecking=no myapp.service cloud-devops@16.171.17.244:/tmp/myapp.service'
                    sh 'scp -o StrictHostKeyChecking=no main cloud-devops@16.171.17.244:/tmp/main'
                    sh '''ssh -o StrictHostKeyChecking=no cloud-devops@16.171.17.244 "
                        sudo cp /tmp/main /usr/local/bin/myapp
                        sudo chmod +x /usr/local/bin/myapp
                        sudo cp /tmp/myapp.service /etc/systemd/system/myapp.service
                        sudo systemctl stop myapp || true
                        sudo systemctl daemon-reload
                        sudo systemctl enable myapp
                        sudo systemctl start myapp
                    "'''
                }
            }
        }
    }
}
