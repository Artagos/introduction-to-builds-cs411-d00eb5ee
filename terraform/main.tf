terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the EC2 deployment. The current Jenkins target IP is in eu-north-1."
  type        = string
  default     = "eu-north-1"
}

variable "instance_name" {
  description = "Name tag used for the EC2 instance and related resources."
  type        = string
  default     = "devopsmod-go-app"
}

variable "instance_type" {
  description = "EC2 instance size for the Go service."
  type        = string
  default     = "t3.micro"
}

variable "public_key" {
  description = "Public half of the SSH key whose private half is stored in Jenkins as credentialsId ssh-key."
  type        = string
  sensitive   = true
}

variable "ssh_cidr_blocks" {
  description = "CIDR ranges allowed to SSH to the instance. Replace the default with your laptop or Jenkins agent IP range."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_cidr_blocks" {
  description = "CIDR ranges allowed to reach the app on TCP/4444."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  description = "Optional VPC ID. Leave null to use the default VPC."
  type        = string
  default     = null
}

data "aws_vpc" "selected" {
  default = var.vpc_id == null ? true : null
  id      = var.vpc_id
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "jenkins" {
  key_name   = "${var.instance_name}-jenkins"
  public_key = var.public_key

  tags = {
    Name = "${var.instance_name}-jenkins"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.instance_name}-sg"
  description = "Allow Jenkins SSH deploys and HTTP traffic to the Go app"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH for Jenkins deploys"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "Go app"
    from_port   = 4444
    to_port     = 4444
    protocol    = "tcp"
    cidr_blocks = var.app_cidr_blocks
  }

  egress {
    description = "Allow outbound traffic for package updates and service calls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.jenkins.key_name
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  tags = {
    Name = var.instance_name
  }
}

output "instance_public_ip" {
  description = "Use this IP in Jenkinsfile where it currently SSHes to the EC2 host."
  value       = aws_instance.app.public_ip
}

output "ssh_target" {
  description = "SSH target matching the current Jenkins deploy user."
  value       = "ec2-user@${aws_instance.app.public_ip}"
}
