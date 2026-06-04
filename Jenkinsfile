pipeline {
    agent any
    tools {
        go '1.24.1'
    }
    environment {
        AWS_DEFAULT_REGION = 'eu-north-1'
        TF_IN_AUTOMATION = 'true'
        DEPLOY_HOST_IP = '16.170.215.199'
    }

    stages {
        stage('Build') {
            steps {
                sh 'CGO_ENABLED=0 go build -o main main.go'
            }
        }
        stage('Provision') {
            steps {
                withCredentials([sshUserPrivateKey(
                        credentialsId: 'ssh-key',
                        keyFileVariable: 'KEY',
                        usernameVariable: 'SSH_USER'),
                    usernamePassword(
                        credentialsId: 'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        sh '''
                            export TF_VAR_public_key="$(ssh-keygen -y -f "$KEY")"
                            terraform init -input=false

                            terraform import aws_key_pair.jenkins devopsmod-go-app-jenkins || true

                            terraform apply -auto-approve -input=false
                        '''
                        script {
                            env.INSTANCE_PUBLIC_IP = env.DEPLOY_HOST_IP
                        }
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(
                        credentialsId: 'ssh-key',
                        keyFileVariable: 'KEY',
                        usernameVariable: 'SSH_USER')]) {
                    sh '''
                        for i in $(seq 1 30); do
                            ssh -i "$KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "ec2-user@$INSTANCE_PUBLIC_IP" "true" && exit 0
                            sleep 5
                        done
                        exit 1
                    '''
                    sh 'scp -i "$KEY" -o StrictHostKeyChecking=no myapp.service "ec2-user@$INSTANCE_PUBLIC_IP:/tmp/myapp.service"'
                    sh 'scp -i "$KEY" -o StrictHostKeyChecking=no main "ec2-user@$INSTANCE_PUBLIC_IP:/tmp/main"'
                    sh '''ssh -i "$KEY" -o StrictHostKeyChecking=no "ec2-user@$INSTANCE_PUBLIC_IP" "
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
