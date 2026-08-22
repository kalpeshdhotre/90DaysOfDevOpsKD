terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- Key Pair --- 
resource "aws_key_pair" "ansible_key" {
  key_name   = "ansible-lab-key"
  public_key = file("~/.ssh/ansible-lab-key.pub")
}

# --- Security Group ---
resource "aws_security_group" "ansible_sg" {
  name        = "ansible-lab-sg"
  description = "Allow SSH for Ansible control node"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten to your IP/32 in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ansible-lab-sg"
  }
}

# --- Ubuntu 22.04 AMI (latest, official Canonical) ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- 3 EC2 Instances ---
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ansible_key.key_name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "web-server"
  }
}

# resource "aws_instance" "app" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t2.micro"
#   key_name               = aws_key_pair.ansible_key.key_name
#   vpc_security_group_ids = [aws_security_group.ansible_sg.id]

#   tags = {
#     Name = "app-server"
#   }
# }

# resource "aws_instance" "db" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t2.micro"
#   key_name               = aws_key_pair.ansible_key.key_name
#   vpc_security_group_ids = [aws_security_group.ansible_sg.id]

#   tags = {
#     Name = "db-server"
#   }
# }
